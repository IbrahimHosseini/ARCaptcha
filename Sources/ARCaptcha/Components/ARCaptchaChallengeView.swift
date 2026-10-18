import SwiftUI
import UIKit

/// The native challenge embedded in your own layout, like the containers of the Android SDK.
///
/// It always uses the native renderer, whatever ``ARCaptchaConfiguration/renderer`` says, because the
/// web widget cannot be laid out inline. Errors show a retry button, and when a token expires a new
/// challenge loads.
///
/// The help button shows a system alert. Pass `onHelp` to show the help in your own alert instead.
///
/// ```swift
/// ARCaptchaChallengeView(configuration: configuration) { token in
///     self.token = token
/// }
/// ```
public struct ARCaptchaChallengeView: View {
    @StateObject private var model: NativeChallengeModel
    private let onEvent: ((ARCaptchaEvent) -> Void)?
    private let onHelp: ((ARCaptchaHelp) -> Void)?
    private let onToken: (ARCaptchaToken) -> Void

    public init(
        configuration: ARCaptchaConfiguration,
        onEvent: ((ARCaptchaEvent) -> Void)? = nil,
        onHelp: ((ARCaptchaHelp) -> Void)? = nil,
        onToken: @escaping (ARCaptchaToken) -> Void
    ) {
        _model = StateObject(wrappedValue: NativeChallengeModel(configuration: configuration, isEmbedded: true))
        self.onEvent = onEvent
        self.onHelp = onHelp
        self.onToken = onToken
    }

    public var body: some View {
        NativeChallengeCard(model: model)
            .modifier(ThemeModifier(theme: model.configuration.theme))
            .onAppear {
                model.onEvent = onEvent
                model.onHelp = onHelp
                model.onSolved = onToken
                model.startIfNeeded()
            }
    }
}

/// A UIKit container for ``ARCaptchaChallengeView``.
///
/// ```swift
/// let challenge = ARCaptchaChallengeViewController(configuration: configuration) { token in
///     self.token = token
/// }
/// addChild(challenge)
/// stackView.addArrangedSubview(challenge.view)
/// challenge.didMove(toParent: self)
/// ```
public final class ARCaptchaChallengeViewController: UIHostingController<ARCaptchaChallengeView> {
    public init(
        configuration: ARCaptchaConfiguration,
        onEvent: ((ARCaptchaEvent) -> Void)? = nil,
        onHelp: ((ARCaptchaHelp) -> Void)? = nil,
        onToken: @escaping (ARCaptchaToken) -> Void
    ) {
        super.init(rootView: ARCaptchaChallengeView(configuration: configuration,
                                                    onEvent: onEvent,
                                                    onHelp: onHelp,
                                                    onToken: onToken))
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) {
            sizingOptions = .intrinsicContentSize
        }
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
