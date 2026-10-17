import Foundation

/// The proof that a user passed an ARCaptcha challenge.
///
/// Send ``value`` to your backend and verify it there with your secret key:
/// `POST https://api.arcaptcha.co/arcaptcha/api/verify` with `challenge_id`, `site_key` and `secret_key`.
/// A token can be verified only once and only for a short time, so verify it right after the user submits.
public struct ARCaptchaToken: Hashable, Sendable, CustomStringConvertible {
    /// The token, sent to the verify endpoint as `challenge_id`.
    public let value: String
    public let issuedAt: Date
    /// When ARCaptcha stops accepting the token. It is an estimate based on ``ARCaptchaConfiguration/tokenLifetime``.
    public let expiresAt: Date

    public init(value: String, issuedAt: Date = Date(), lifetime: TimeInterval) {
        self.value = value
        self.issuedAt = issuedAt
        self.expiresAt = issuedAt.addingTimeInterval(lifetime)
    }

    public var isExpired: Bool { Date() >= expiresAt }

    public var description: String { value }
}
