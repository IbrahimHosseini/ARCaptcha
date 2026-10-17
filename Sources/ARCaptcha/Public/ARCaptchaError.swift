import Foundation

/// An error produced while verifying a user with ARCaptcha.
///
/// Codes `101`–`401` mirror the error codes of the ARCaptcha web widget and the Android SDKs,
/// so they can be logged and handled the same way on every platform. Codes from `1000` up are
/// specific to this SDK.
///
/// ```swift
/// do {
///     let token = try await captcha.verify()
/// } catch let error as ARCaptchaError where error.code == .cancelled {
///     // The user closed the challenge.
/// }
/// ```
public struct ARCaptchaError: Error, Hashable, Sendable {
    public enum Code: Int, Hashable, Sendable, CaseIterable {
        /// ARCaptcha failed to create a challenge, for example because the site key or domain is not registered.
        case createServerError = 101
        /// The device could not reach ARCaptcha while creating a challenge.
        case createNetworkError = 102
        /// ARCaptcha failed to validate the answer.
        case answerServerError = 201
        /// The device could not reach ARCaptcha while submitting the answer.
        case answerNetworkError = 202
        /// The submitted answer was wrong.
        case answerWrong = 203
        /// An unclassified error.
        case unknown = 401
        /// The user dismissed the challenge, or ``ARCaptcha/cancel()`` was called.
        case cancelled = 1000
        /// The challenge did not load within ``ARCaptchaConfiguration/loadingTimeout``.
        case timeout = 1001
        /// ARCaptcha classified the client as a bot and refused to show a challenge.
        case blocked = 1002
        /// The configuration is not usable, for example the site key is empty.
        case invalidConfiguration = 1003
        /// There is no foreground window scene to present the challenge in.
        case presentationFailed = 1004
        /// ``ARCaptcha/verify(presentation:in:)`` was called while a verification was already running.
        case alreadyInProgress = 1005
    }

    public let code: Code
    /// A developer-facing description. It is not localized and should not be shown to users as is.
    public let message: String

    public init(code: Code, message: String = "") {
        self.code = code
        self.message = message
    }
}

extension ARCaptchaError: LocalizedError {
    public var errorDescription: String? {
        message.isEmpty ? "ARCaptcha error \(code.rawValue)" : "ARCaptcha error \(code.rawValue): \(message)"
    }
}

extension ARCaptchaError {
    public static let cancelled = ARCaptchaError(code: .cancelled, message: "The challenge was dismissed.")
    public static let timeout = ARCaptchaError(code: .timeout, message: "The challenge did not load in time.")
    public static let blocked = ARCaptchaError(code: .blocked, message: "ARCaptcha refused to show a challenge to this client.")

    /// Maps an error reported by the web widget's `error_callback` to an SDK error.
    init(widgetCode: Int, message: String) {
        self.init(code: Code(rawValue: widgetCode) ?? .unknown, message: message)
    }
}
