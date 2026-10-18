import AVFoundation
import Combine

/// Plays the clip of an audio challenge.
@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false

    private let session: AudioSessionSwitcher?
    private var player: AVPlayer?
    private var observers: [any NSObjectProtocol] = []
    /// Changes on every stop, so a clip whose session switch finishes after a stop never starts.
    private var playbackID = 0

    init(managesSession: Bool) {
        self.session = managesSession ? AudioSessionSwitcher() : nil
    }

    func play(_ url: URL) {
        stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            })
        }
        self.player = player
        isPlaying = true
        guard let session else { return player.play() }
        // Starts once the session is in playback, so the clip is heard even with the ringer off.
        let id = playbackID
        session.activate { [weak self] in
            guard let self, self.playbackID == id else { return }
            self.player?.play()
        }
    }

    func stop() {
        playbackID += 1
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        player?.pause()
        player = nil
        if isPlaying { isPlaying = false }
        session?.restore()
    }
}

/// Switches the shared audio session to playback for a clip and back to what the app had.
/// `AVAudioSession` calls can block for a while, so they run in order on a private queue
/// instead of the main thread.
private final class AudioSessionSwitcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "co.arcaptcha.audio-session", qos: .userInitiated)
    /// Only touched on `queue`.
    private var saved: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?

    func activate(then completion: @escaping @MainActor @Sendable () -> Void) {
        queue.async {
            if self.saved == nil {
                let session = AVAudioSession.sharedInstance()
                self.saved = (session.category, session.mode, session.categoryOptions)
                try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try? session.setActive(true)
            }
            Task { @MainActor in completion() }
        }
    }

    func restore() {
        queue.async {
            guard let saved = self.saved else { return }
            self.saved = nil
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(saved.category, mode: saved.mode, options: saved.options)
            // An app on the default category was not playing audio of its own; let others resume.
            if saved.category == .soloAmbient {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
}
