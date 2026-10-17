import AVFoundation
import Combine

/// Plays the clip of an audio challenge.
@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false

    private let managesSession: Bool
    private var player: AVPlayer?
    private var observers: [any NSObjectProtocol] = []
    private var savedSession: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?

    init(managesSession: Bool) {
        self.managesSession = managesSession
    }

    func play(_ url: URL) {
        stop()
        activateSession()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            })
        }
        self.player = player
        player.play()
        isPlaying = true
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        player?.pause()
        player = nil
        if isPlaying { isPlaying = false }
        restoreSession()
    }

    private func activateSession() {
        guard managesSession, savedSession == nil else { return }
        let session = AVAudioSession.sharedInstance()
        savedSession = (session.category, session.mode, session.categoryOptions)
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func restoreSession() {
        guard let saved = savedSession else { return }
        savedSession = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(saved.category, mode: saved.mode, options: saved.options)
        // An app on the default category was not playing audio of its own; let others resume.
        if saved.category == .soloAmbient {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
