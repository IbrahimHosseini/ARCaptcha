import UIKit

/// One run of ``ARCaptcha/verify(presentation:in:)``: owns the overlay window and the renderer,
/// and turns their output into a single result.
@MainActor
final class VerificationSession {
    private let configuration: ARCaptchaConfiguration
    private let presentation: ARCaptchaPresentation
    private let onEvent: (ARCaptchaEvent) -> Void
    private var renderer: (any ChallengeRenderer)?
    private var window: OverlayWindow?
    private var overlay: OverlayViewController?
    private weak var previousKeyWindow: UIWindow?
    private var continuation: CheckedContinuation<ARCaptchaToken, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var isPresented = false

    init(configuration: ARCaptchaConfiguration, presentation: ARCaptchaPresentation, onEvent: @escaping (ARCaptchaEvent) -> Void) {
        self.configuration = configuration
        self.presentation = presentation
        self.onEvent = onEvent
    }

    func run(in scene: UIWindowScene) async throws -> ARCaptchaToken {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.start(in: scene)
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    func cancel() {
        finish(.failure(.cancelled))
    }

    private func start(in scene: UIWindowScene) {
        let renderer: any ChallengeRenderer = switch configuration.renderer {
        case .web: WebChallengeRenderer(configuration: configuration)
        case .native: NativeChallengeRenderer(configuration: configuration)
        }
        renderer.output = { [weak self] output in self?.handle(output) }
        self.renderer = renderer

        let overlay = OverlayViewController(
            content: renderer.viewController,
            hidesContentUntilPresented: renderer.hidesContentUntilPresented,
            appearance: configuration.appearance,
            strings: configuration.resolvedStrings
        )
        overlay.onClose = { [weak self] in self?.cancel() }
        self.overlay = overlay

        let window = OverlayWindow(windowScene: scene)
        window.windowLevel = .alert - 1
        window.backgroundColor = .clear
        window.overrideUserInterfaceStyle = configuration.theme.interfaceStyle
        window.rootViewController = overlay
        window.isHidden = false
        self.window = window
        previousKeyWindow = scene.windows.first { $0.isKeyWindow }

        if presentation == .modal {
            showOverlay(loading: true)
        }
        startTimeout()
        renderer.start()
    }

    private func handle(_ output: RendererOutput) {
        switch output {
        case let .event(event):
            onEvent(event)
        case .needsPresentation:
            timeoutTask?.cancel()
            showOverlay(loading: false)
            onEvent(.challengePresented)
        case let .solved(token):
            onEvent(.tokenIssued)
            finish(.success(token))
        case let .failed(error):
            finish(.failure(error))
        case .dismissed:
            finish(.failure(.cancelled))
        }
    }

    private func showOverlay(loading: Bool) {
        guard let window, let overlay else { return }
        window.passesTouchesThrough = false
        window.makeKey()
        overlay.reveal(loading: loading, animated: true)
        isPresented = true
    }

    private func startTimeout() {
        let timeout = configuration.loadingTimeout
        guard timeout > 0 else { return }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(.failure(.timeout))
        }
    }

    private func finish(_ result: Result<ARCaptchaToken, ARCaptchaError>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        renderer?.stop()
        if case let .failure(error) = result, error.code != .cancelled {
            onEvent(.failed(error))
        }

        let complete = { [self] in
            window?.isHidden = true
            window?.rootViewController = nil
            window = nil
            overlay = nil
            renderer = nil
            if isPresented { previousKeyWindow?.makeKey() }
            onEvent(.closed)
            continuation.resume(with: result.mapError { $0 as any Error })
        }
        if isPresented, let overlay {
            overlay.conceal(completion: complete)
        } else {
            complete()
        }
    }
}
