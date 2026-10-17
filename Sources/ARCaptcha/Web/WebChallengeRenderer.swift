import UIKit
@preconcurrency import WebKit

/// Runs ARCaptcha's official web widget in a transparent, full-screen web view.
@MainActor
final class WebChallengeRenderer: NSObject, ChallengeRenderer {
    let viewController: UIViewController
    let hidesContentUntilPresented = false
    var output: ((RendererOutput) -> Void)?

    private let configuration: ARCaptchaConfiguration
    private let webView: WKWebView
    private var isChallengeOpen = false
    private var pendingError: ARCaptchaError?
    private var isFinished = false

    init(configuration: ARCaptchaConfiguration) {
        self.configuration = configuration

        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webConfiguration.applicationNameForUserAgent = "ARCaptcha-iOS/\(ARCaptcha.sdkVersion)"
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 16.4, *) {
            webView.isInspectable = configuration.web.isInspectable
        }

        let controller = UIViewController()
        controller.view = webView
        viewController = controller
        super.init()

        webConfiguration.userContentController.add(WeakScriptMessageHandler(self), name: WebWidgetDocument.messageHandlerName)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func start() {
        output?(.event(.loading))
        let isDark = viewController.traitCollection.userInterfaceStyle == .dark
            || (configuration.theme == .automatic && UITraitCollection.current.userInterfaceStyle == .dark)
        let document = WebWidgetDocument(configuration: configuration, isDark: isDark)
        webView.loadHTMLString(document.html, baseURL: document.baseURL)
    }

    func stop() {
        isFinished = true
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: WebWidgetDocument.messageHandlerName)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    func handle(_ message: WebBridgeMessage) {
        guard !isFinished else { return }
        switch message {
        case .ready, .rendered, .expired:
            break
        case .opened:
            isChallengeOpen = true
            pendingError = nil
            output?(.event(.challengeLoaded(nil)))
            output?(.needsPresentation)
        case let .token(value):
            finish(.solved(ARCaptchaToken(value: value, lifetime: configuration.tokenLifetime)))
        case let .error(code, text):
            let error = ARCaptchaError(widgetCode: code, message: text)
            if error.code == .answerWrong {
                // The widget shows a new challenge by itself.
                output?(.event(.answerRejected))
            } else if isChallengeOpen {
                // The widget reports the error to the user and then closes the challenge.
                pendingError = error
            } else {
                finish(.failed(error))
            }
        case .closed:
            isChallengeOpen = false
            finish(pendingError.map(RendererOutput.failed) ?? .dismissed)
        case .blocked:
            finish(.failed(.blocked))
        case .challengeExpired:
            output?(.event(.challengeExpired))
        }
    }

    private func finish(_ result: RendererOutput) {
        guard !isFinished else { return }
        isFinished = true
        output?(result)
    }

    private func openExternally(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return }
        UIApplication.shared.open(url)
    }
}

extension WebChallengeRenderer: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let parsed = WebBridgeMessage(body: message.body) else { return }
        handle(parsed)
    }
}

extension WebChallengeRenderer: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // Links such as the ARCaptcha brand open in the browser instead of replacing the widget.
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            openExternally(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        finish(.failed(ARCaptchaError(code: .createNetworkError, message: error.localizedDescription)))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        finish(.failed(ARCaptchaError(code: .createNetworkError, message: error.localizedDescription)))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(.failed(ARCaptchaError(code: .unknown, message: "The web content process terminated.")))
    }
}

extension WebChallengeRenderer: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            openExternally(url)
        }
        return nil
    }
}

/// Breaks the retain cycle between `WKUserContentController` and its handler.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler)?

    init(_ target: any WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
