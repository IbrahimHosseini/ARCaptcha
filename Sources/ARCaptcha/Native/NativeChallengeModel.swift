import SwiftUI
import UIKit

/// A challenge with its images decoded, ready to display.
struct NativeChallenge {
    enum Kind {
        case imageSelection(category: String, images: [UIImage])
        case puzzle(background: UIImage, piece: UIImage, pieceY: CGFloat)
        case audio(url: URL)
    }

    let id: String
    let kind: Kind

    var type: ARCaptchaChallengeType {
        switch kind {
        case .imageSelection: .imageSelection
        case .puzzle: .puzzle
        case .audio: .audio
        }
    }

    init(payload: NativeChallengePayload) throws {
        id = payload.id
        switch payload.kind {
        case let .imageSelection(category, data):
            let images = data.compactMap { UIImage(data: $0) }
            guard !images.isEmpty, images.count == data.count else {
                throw ARCaptchaError(code: .createServerError, message: "The challenge images could not be decoded.")
            }
            kind = .imageSelection(category: category, images: images)
        case let .puzzle(backgroundData, pieceData, pieceY):
            // Scale 1 keeps image sizes in the 260×160 coordinate space the answer is measured in.
            guard let background = UIImage(data: backgroundData, scale: 1), let piece = UIImage(data: pieceData, scale: 1) else {
                throw ARCaptchaError(code: .createServerError, message: "The puzzle images could not be decoded.")
            }
            kind = .puzzle(background: background, piece: piece, pieceY: CGFloat(pieceY))
        case let .audio(url):
            kind = .audio(url: url)
        }
    }
}

/// Drives one native challenge: loading, user input, submission and expiry.
@MainActor
final class NativeChallengeModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case submitting
        case solved
        case rejected
        case failed
    }

    enum Mode {
        case visual
        case audio
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var challenge: NativeChallenge?
    @Published private(set) var mode: Mode
    @Published private(set) var selection: Set<Int> = []
    /// The puzzle piece's x position in the original 260-point-wide image.
    @Published var puzzleOffset: CGFloat = 0
    @Published var audioAnswer = "" {
        didSet { if !audioAnswer.isEmpty { noteInteraction() } }
    }

    let configuration: ARCaptchaConfiguration
    let strings: ARCaptchaStrings
    let audioPlayer: AudioPlayer

    var onEvent: ((ARCaptchaEvent) -> Void)?
    /// Called each time a challenge is ready for the user.
    var onChallengeReady: (() -> Void)?
    var onSolved: ((ARCaptchaToken) -> Void)?
    /// Called on errors when the model is not embedded. Embedded models show a retry button instead.
    var onFailure: ((ARCaptchaError) -> Void)?

    private let client: NativeAPIClient
    private let isEmbedded: Bool
    private var task: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var hasStarted = false
    private var hasInteracted = false
    private var selectionTimestamps: [Date] = []
    private var dragStart: (date: Date, offset: CGFloat)?

    /// - Parameter isEmbedded: `true` when the challenge lives inside the host's layout and should
    ///   recover from errors and token expiry by itself.
    init(configuration: ARCaptchaConfiguration, isEmbedded: Bool, session: URLSession = .shared) {
        self.configuration = configuration
        self.strings = configuration.resolvedStrings
        self.isEmbedded = isEmbedded
        self.client = NativeAPIClient(configuration: configuration, session: session)
        self.audioPlayer = AudioPlayer(managesSession: configuration.native.managesAudioSession)
        self.mode = configuration.native.preferredChallenge == .audio ? .audio : .visual
    }

    var isInteractive: Bool { phase == .ready }
    var allowsAudio: Bool { configuration.native.allowsAudioChallenge }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        load()
    }

    func load() {
        cancelWork()
        audioPlayer.stop()
        phase = .loading
        challenge = nil
        resetInput()
        onEvent?(.loading)

        let type = requestedType
        task = Task { [weak self, client] in
            do {
                let outcome = try await client.createChallenge(type)
                guard let self, !Task.isCancelled else { return }
                switch outcome {
                case let .passed(token):
                    self.complete(with: token)
                case let .challenge(payload):
                    self.present(try NativeChallenge(payload: payload))
                }
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.fail(error as? ARCaptchaError ?? ARCaptchaError(code: .unknown, message: error.localizedDescription))
            }
        }
    }

    func switchMode() {
        guard allowsAudio, phase != .submitting else { return }
        mode = mode == .visual ? .audio : .visual
        load()
    }

    /// Stops network work, timers and audio. Call it when the challenge leaves the screen for good.
    func stop() {
        cancelWork()
        audioPlayer.stop()
    }

    // MARK: Image selection

    func toggleImage(_ index: Int) {
        guard phase == .ready else { return }
        noteInteraction()
        if selection.contains(index) {
            selection.remove(index)
            if selectionTimestamps.count > 1 { selectionTimestamps.removeLast() }
        } else {
            selection.insert(index)
            selectionTimestamps.append(Date())
        }
    }

    func submitImageSelection() {
        guard case let .imageSelection(_, images) = challenge?.kind else { return }
        let picks = images.indices.map { selection.contains($0) }
        submit(.imageSelection(selection: picks, intervals: AnswerEncoding.intervals(between: selectionTimestamps)))
    }

    // MARK: Puzzle

    func beginPuzzleDrag() {
        guard phase == .ready, dragStart == nil else { return }
        noteInteraction()
        dragStart = (Date(), puzzleOffset)
    }

    func endPuzzleDrag() {
        guard let start = dragStart else { return }
        dragStart = nil
        let duration = max(0, Int((Date().timeIntervalSince(start.date) * 1000).rounded()))
        let speed = AnswerEncoding.dragSpeed(distance: Double(puzzleOffset - start.offset), milliseconds: duration)
        submit(.puzzle(offset: Int(puzzleOffset.rounded()), speed: speed, duration: duration))
    }

    // MARK: Audio

    func toggleAudioPlayback() {
        guard case let .audio(url) = challenge?.kind else { return }
        if audioPlayer.isPlaying {
            audioPlayer.stop()
        } else {
            audioPlayer.play(url)
        }
    }

    func submitAudioAnswer() {
        let text = audioAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        submit(.audio(text))
    }

    // MARK: Private

    private var requestedType: ARCaptchaChallengeType {
        if mode == .audio { return .audio }
        let preferred = configuration.native.preferredChallenge
        return preferred == .audio ? .imageSelection : preferred
    }

    private func present(_ challenge: NativeChallenge) {
        self.challenge = challenge
        phase = .ready
        onEvent?(.challengeLoaded(challenge.type))
        onChallengeReady?()
        scheduleChallengeExpiry()
        if case let .audio(url) = challenge.kind {
            audioPlayer.play(url)
        }
    }

    private func submit(_ answer: NativeAnswer) {
        guard phase == .ready, let challenge else { return }
        phase = .submitting
        audioPlayer.stop()
        expiryTask?.cancel()
        onEvent?(.answerSubmitted)

        task = Task { [weak self, client] in
            do {
                let outcome = try await client.submit(answer, challengeID: challenge.id)
                guard let self, !Task.isCancelled else { return }
                switch outcome {
                case .correct:
                    self.phase = .solved
                    Haptics.notify(.success)
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    guard !Task.isCancelled else { return }
                    self.complete(with: challenge.id)
                case .incorrect, .expired:
                    self.phase = .rejected
                    Haptics.notify(.error)
                    self.onEvent?(.answerRejected)
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    guard !Task.isCancelled else { return }
                    self.load()
                }
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.fail(error as? ARCaptchaError ?? ARCaptchaError(code: .unknown, message: error.localizedDescription))
            }
        }
    }

    private func complete(with value: String) {
        expiryTask?.cancel()
        phase = .solved
        let token = ARCaptchaToken(value: value, lifetime: configuration.tokenLifetime)
        onEvent?(.tokenIssued)
        onSolved?(token)
        guard isEmbedded else { return }
        // An embedded challenge offers a fresh one once the token can no longer be used.
        let lifetime = configuration.tokenLifetime
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.onEvent?(.tokenExpired)
            self.load()
        }
    }

    private func fail(_ error: ARCaptchaError) {
        audioPlayer.stop()
        expiryTask?.cancel()
        phase = .failed
        onEvent?(.failed(error))
        if !isEmbedded {
            onFailure?(error)
        }
    }

    private func scheduleChallengeExpiry() {
        expiryTask?.cancel()
        let lifetime = configuration.tokenLifetime
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard let self, !Task.isCancelled, self.phase == .ready else { return }
            self.onEvent?(.challengeExpired)
            self.load()
        }
    }

    private func noteInteraction() {
        guard !hasInteracted, phase == .ready else { return }
        hasInteracted = true
        onEvent?(.answerStarted)
    }

    private func resetInput() {
        hasInteracted = false
        selection = []
        selectionTimestamps = [Date()]
        puzzleOffset = 0
        dragStart = nil
        audioAnswer = ""
    }

    private func cancelWork() {
        task?.cancel()
        task = nil
        expiryTask?.cancel()
        expiryTask = nil
    }
}

enum Haptics {
    @MainActor
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
