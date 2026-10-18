import UIKit

/// Verifies that the user is human with ARCaptcha.
///
/// ```swift
/// let captcha = ARCaptcha(siteKey: "YOUR_SITE_KEY", domain: "example.com")
/// let token = try await captcha.verify()
/// // Send token.value to your backend and verify it with your secret key.
/// ```
///
/// For a checkbox inside a form use ``ARCaptchaCheckbox`` (SwiftUI) or ``ARCaptchaCheckboxView`` (UIKit).
/// To embed the native challenge itself use ``ARCaptchaChallengeView``.
@MainActor
public final class ARCaptcha {
    /// The version of this SDK.
    public nonisolated static let sdkVersion = "1.0.2"

    public let configuration: ARCaptchaConfiguration
    /// Receives lifecycle events of every verification run by this instance.
    public var onEvent: ((ARCaptchaEvent) -> Void)?
    public var isVerifying: Bool { session != nil }

    private var session: VerificationSession?

    public init(configuration: ARCaptchaConfiguration) {
        self.configuration = configuration
    }

    public convenience init(siteKey: String, domain: String) {
        self.init(configuration: ARCaptchaConfiguration(siteKey: siteKey, domain: domain))
    }

    /// Shows a challenge if one is needed and returns a token once the user passes.
    ///
    /// The challenge appears in its own window above your app, so it works from SwiftUI and UIKit alike.
    ///
    /// - Parameters:
    ///   - presentation: ``ARCaptchaPresentation/modal`` dims the screen right away;
    ///     ``ARCaptchaPresentation/invisible`` shows nothing unless the user must solve a challenge.
    ///   - windowScene: The scene to show the challenge in. `nil` uses the foreground scene.
    /// - Throws: ``ARCaptchaError``. Cancelling the calling task dismisses the challenge and throws
    ///   ``ARCaptchaError/Code/cancelled``.
    public func verify(presentation: ARCaptchaPresentation = .modal, in windowScene: UIWindowScene? = nil) async throws -> ARCaptchaToken {
        try configuration.validate()
        guard session == nil else {
            throw ARCaptchaError(code: .alreadyInProgress, message: "A verification is already running.")
        }
        guard let scene = windowScene ?? Self.foregroundScene() else {
            throw ARCaptchaError(code: .presentationFailed, message: "There is no foreground window scene.")
        }
        let session = VerificationSession(configuration: configuration, presentation: presentation) { [weak self] event in
            self?.onEvent?(event)
        }
        self.session = session
        defer { self.session = nil }
        return try await session.run(in: scene)
    }

    /// Shows a challenge from a view controller's scene. See ``verify(presentation:in:)``.
    public func verify(presentation: ARCaptchaPresentation = .modal, from viewController: UIViewController) async throws -> ARCaptchaToken {
        try await verify(presentation: presentation, in: viewController.view.window?.windowScene)
    }

    /// A completion-handler version of ``verify(presentation:in:)``.
    public func verify(
        presentation: ARCaptchaPresentation = .modal,
        in windowScene: UIWindowScene? = nil,
        completion: @escaping @MainActor (Result<ARCaptchaToken, ARCaptchaError>) -> Void
    ) {
        Task {
            do {
                completion(.success(try await verify(presentation: presentation, in: windowScene)))
            } catch {
                completion(.failure(error as? ARCaptchaError ?? ARCaptchaError(code: .unknown, message: error.localizedDescription)))
            }
        }
    }

    /// Dismisses the current challenge. The pending `verify` call throws ``ARCaptchaError/Code/cancelled``.
    public func cancel() {
        session?.cancel()
    }

    private static func foregroundScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
    }
}
