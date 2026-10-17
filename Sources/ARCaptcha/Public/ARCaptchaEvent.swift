import Foundation

/// The kinds of challenge ARCaptcha can ask a user to solve.
public enum ARCaptchaChallengeType: String, Hashable, Sendable, CaseIterable {
    /// Pick every image that matches a category, from a grid of nine.
    case imageSelection
    /// Drag a slider to fit a puzzle piece into its slot.
    case puzzle
    /// Type what is said in an audio clip.
    case audio
}

/// How a verification is shown to the user.
public enum ARCaptchaPresentation: Hashable, Sendable {
    /// Dims the screen right away and shows a loading indicator until the challenge appears.
    case modal
    /// Shows nothing unless ARCaptcha decides the user must solve a challenge.
    case invisible
}

/// Lifecycle events, for analytics or for adapting your own UI.
public enum ARCaptchaEvent: Hashable, Sendable {
    /// A challenge is being requested.
    case loading
    /// A challenge is ready. The type is `nil` for the web renderer, which does not report it.
    case challengeLoaded(ARCaptchaChallengeType?)
    /// The challenge became visible to the user.
    case challengePresented
    /// The user started interacting with the challenge.
    case answerStarted
    /// The answer was sent to ARCaptcha.
    case answerSubmitted
    /// ARCaptcha rejected the answer. A new challenge follows.
    case answerRejected
    /// The challenge expired before it was answered. A new challenge follows.
    case challengeExpired
    /// The user passed and a token was issued.
    case tokenIssued
    /// A token issued earlier is no longer valid.
    case tokenExpired
    /// The verification failed.
    case failed(ARCaptchaError)
    /// The challenge UI was removed from the screen.
    case closed
}
