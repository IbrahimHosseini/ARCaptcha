import SwiftUI
import UIKit

/// An "I'm not a robot" checkbox for forms.
///
/// Tapping it runs an invisible verification: the user only sees a challenge if ARCaptcha asks for one.
/// The token is cleared when it expires, and you can clear it yourself after using it, because
/// a token can be verified only once.
///
/// ```swift
/// @State private var token: ARCaptchaToken?
///
/// ARCaptchaCheckbox(configuration: configuration, token: $token)
/// Button("Sign up") { signUp(captchaToken: token!.value); token = nil }
///     .disabled(token == nil)
/// ```
public struct ARCaptchaCheckbox: View {
    @Binding private var token: ARCaptchaToken?
    @StateObject private var controller: CheckboxController

    public init(
        configuration: ARCaptchaConfiguration,
        token: Binding<ARCaptchaToken?>,
        onEvent: ((ARCaptchaEvent) -> Void)? = nil,
        onError: ((ARCaptchaError) -> Void)? = nil
    ) {
        _token = token
        _controller = StateObject(wrappedValue: CheckboxController(configuration: configuration, onEvent: onEvent, onError: onError))
    }

    public var body: some View {
        CheckboxBody(controller: controller)
            .onChange(of: controller.token) { token = $0 }
            .onChange(of: token) { newValue in
                if newValue == nil, controller.token != nil { controller.reset() }
            }
    }
}

@MainActor
final class CheckboxController: ObservableObject {
    enum State: Equatable {
        case idle
        case verifying
        case verified
        case failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var token: ARCaptchaToken?

    let configuration: ARCaptchaConfiguration
    var onEvent: ((ARCaptchaEvent) -> Void)?
    var onError: ((ARCaptchaError) -> Void)?

    private let captcha: ARCaptcha
    private var expiryTask: Task<Void, Never>?

    init(configuration: ARCaptchaConfiguration, onEvent: ((ARCaptchaEvent) -> Void)?, onError: ((ARCaptchaError) -> Void)?) {
        self.configuration = configuration
        self.onEvent = onEvent
        self.onError = onError
        captcha = ARCaptcha(configuration: configuration)
        captcha.onEvent = { [weak self] event in self?.onEvent?(event) }
    }

    func verify(in scene: UIWindowScene?) {
        guard state != .verifying, state != .verified else { return }
        state = .verifying
        Task {
            do {
                let token = try await captcha.verify(presentation: .invisible, in: scene)
                accept(token)
            } catch let error as ARCaptchaError where error.code == .cancelled {
                state = .idle
            } catch {
                state = .failed
                onError?(error as? ARCaptchaError ?? ARCaptchaError(code: .unknown, message: error.localizedDescription))
            }
        }
    }

    func reset() {
        expiryTask?.cancel()
        captcha.cancel()
        token = nil
        state = .idle
    }

    private func accept(_ token: ARCaptchaToken) {
        self.token = token
        state = .verified
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            let delay = max(token.expiresAt.timeIntervalSinceNow, 0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.reset()
            self.onEvent?(.tokenExpired)
        }
    }
}

struct CheckboxBody: View {
    @ObservedObject var controller: CheckboxController
    /// Used to show the challenge in the checkbox's own scene.
    @State private var anchor = SceneAnchor()

    private var appearance: ARCaptchaAppearance { controller.configuration.appearance }
    private var strings: ARCaptchaStrings { controller.configuration.resolvedStrings }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                controller.verify(in: anchor.view?.window?.windowScene)
            } label: {
                HStack(spacing: 12) {
                    box
                    Text(controller.state == .verified ? strings.checkboxVerified : strings.checkboxTitle)
                        .font(appearance.font(.body, size: 16, weight: .semibold))
                        .foregroundColor(Color(uiColor: appearance.primaryTextColor))
                    Spacer(minLength: 8)
                    if appearance.showsBranding {
                        VStack(spacing: 2) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(uiColor: appearance.accentColor))
                            Text(strings.brandName)
                                .font(appearance.font(.caption2, size: 11, weight: .medium))
                                .foregroundColor(Color(uiColor: appearance.secondaryTextColor))
                        }
                        .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                        .fill(Color(uiColor: appearance.backgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                        .stroke(Color(uiColor: appearance.secondaryTextColor).opacity(0.35), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(controller.state == .verifying || controller.state == .verified)
            .accessibilityLabel(strings.checkboxTitle)
            .accessibilityValue(controller.state == .verified ? strings.checkboxVerified : "")
            .accessibilityAddTraits(controller.state == .verified ? [.isButton, .isSelected] : .isButton)
            .background(SceneAnchorView(anchor: anchor).allowsHitTesting(false))

            if controller.state == .failed {
                Text(strings.checkboxFailed)
                    .font(appearance.font(.footnote, size: 13))
                    .foregroundColor(Color(uiColor: appearance.errorColor))
            }
        }
        .environment(\.layoutDirection, controller.configuration.language.isRightToLeft ? .rightToLeft : .leftToRight)
        .modifier(ThemeModifier(theme: controller.configuration.theme))
        .animation(.easeInOut(duration: 0.2), value: controller.state)
    }

    private var box: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(controller.state == .verified ? Color(uiColor: appearance.successColor) : Color(uiColor: appearance.fieldBackgroundColor))
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(uiColor: controller.state == .failed ? appearance.errorColor : appearance.secondaryTextColor), lineWidth: 1.5)
                .opacity(controller.state == .verified ? 0 : 1)
            switch controller.state {
            case .verifying:
                ProgressView().scaleEffect(0.8)
            case .verified:
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            case .idle, .failed:
                EmptyView()
            }
        }
        .frame(width: 28, height: 28)
    }
}

/// Applies a fixed theme to SDK views, or leaves the system's.
struct ThemeModifier: ViewModifier {
    let theme: ARCaptchaTheme

    func body(content: Content) -> some View {
        if let scheme = theme.colorScheme {
            content.environment(\.colorScheme, scheme)
        } else {
            content
        }
    }
}

/// Holds a UIKit view inside a SwiftUI hierarchy, to find the window scene it is shown in.
@MainActor
final class SceneAnchor {
    weak var view: UIView?
}

struct SceneAnchorView: UIViewRepresentable {
    let anchor: SceneAnchor

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        anchor.view = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        anchor.view = uiView
    }
}
