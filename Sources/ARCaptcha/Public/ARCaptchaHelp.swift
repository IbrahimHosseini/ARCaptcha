import Foundation

/// The help shown for the current challenge, for hosts that present it in their own alert.
///
/// Pass `onHelp` to ``ARCaptchaChallengeView`` or ``ARCaptchaChallengeViewController`` to receive it
/// when the user taps the help button. Without `onHelp`, ARCaptcha shows it in a system alert.
public struct ARCaptchaHelp: Hashable, Sendable {
    /// The alert title, ``ARCaptchaStrings/help``.
    public let title: String
    /// How to solve the current challenge type.
    public let message: String
    /// The title of the button that closes the alert, ``ARCaptchaStrings/ok``.
    public let dismissTitle: String

    public init(title: String, message: String, dismissTitle: String) {
        self.title = title
        self.message = message
        self.dismissTitle = dismissTitle
    }
}
