import SwiftUI
import UIKit

extension View {
    /// Runs a verification while `isPresented` is `true`, then sets it back to `false`.
    ///
    /// ```swift
    /// Button("Send code") { showsCaptcha = true }
    ///     .arcaptcha(isPresented: $showsCaptcha, configuration: configuration) { result in
    ///         if case let .success(token) = result { sendCode(captchaToken: token.value) }
    ///     }
    /// ```
    ///
    /// Setting `isPresented` to `false` early dismisses the challenge with ``ARCaptchaError/Code/cancelled``.
    public func arcaptcha(
        isPresented: Binding<Bool>,
        configuration: ARCaptchaConfiguration,
        presentation: ARCaptchaPresentation = .modal,
        onEvent: ((ARCaptchaEvent) -> Void)? = nil,
        onCompletion: @escaping (Result<ARCaptchaToken, ARCaptchaError>) -> Void
    ) -> some View {
        modifier(ARCaptchaPresenter(
            isPresented: isPresented,
            configuration: configuration,
            presentation: presentation,
            onEvent: onEvent,
            onCompletion: onCompletion
        ))
    }
}

private struct ARCaptchaPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let configuration: ARCaptchaConfiguration
    let presentation: ARCaptchaPresentation
    let onEvent: ((ARCaptchaEvent) -> Void)?
    let onCompletion: (Result<ARCaptchaToken, ARCaptchaError>) -> Void

    @State private var task: Task<Void, Never>?
    @State private var anchor = SceneAnchor()

    func body(content: Content) -> some View {
        content
            .background(SceneAnchorView(anchor: anchor).allowsHitTesting(false))
            .onAppear { update(isPresented) }
            .onChange(of: isPresented) { update($0) }
    }

    private func update(_ presented: Bool) {
        if presented {
            guard task == nil else { return }
            let captcha = ARCaptcha(configuration: configuration)
            captcha.onEvent = onEvent
            let scene = anchor.view?.window?.windowScene
            task = Task { @MainActor in
                let result: Result<ARCaptchaToken, ARCaptchaError>
                do {
                    result = .success(try await captcha.verify(presentation: presentation, in: scene))
                } catch {
                    result = .failure(error as? ARCaptchaError ?? ARCaptchaError(code: .unknown, message: error.localizedDescription))
                }
                task = nil
                isPresented = false
                onCompletion(result)
            }
        } else {
            task?.cancel()
        }
    }
}
