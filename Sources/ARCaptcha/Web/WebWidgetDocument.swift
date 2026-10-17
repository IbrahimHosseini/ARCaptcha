import Foundation

/// The HTML page that hosts ARCaptcha's widget in a web view and bridges its callbacks to Swift.
struct WebWidgetDocument: Equatable {
    static let messageHandlerName = "arcaptcha"

    let html: String
    let baseURL: URL

    /// - Parameter isDark: the resolved theme, used when the configuration follows the system.
    init(configuration: ARCaptchaConfiguration, isDark: Bool) {
        var scriptURL = configuration.web.scriptURL.absoluteString
        if var components = URLComponents(url: configuration.web.scriptURL, resolvingAgainstBaseURL: false) {
            let existing = components.queryItems ?? []
            components.queryItems = existing + [URLQueryItem(name: "domain", value: configuration.domain)]
            scriptURL = components.url?.absoluteString ?? scriptURL
        }

        let theme: String = switch configuration.theme {
        case .automatic: isDark ? "dark" : "light"
        case .light: "light"
        case .dark: "dark"
        }
        var settings: [String: Any] = [
            "site_key": configuration.siteKey,
            "lang": configuration.language.rawValue,
            "theme": theme,
            "error_print": configuration.web.showsErrorMessages ? 1 : 0,
        ]
        if let color = configuration.web.color, !color.isEmpty {
            settings["color"] = color
        }

        html = Self.template
            .replacingOccurrences(of: "__SETTINGS__", with: Self.scriptLiteral(settings))
            .replacingOccurrences(of: "__HANDLER__", with: Self.messageHandlerName)
            .replacingOccurrences(of: "__SCRIPT_URL__", with: Self.attributeEscaped(scriptURL))
        baseURL = configuration.web.baseURL ?? URL(string: "https://\(configuration.domain)/") ?? URL(string: "https://localhost/")!
    }

    /// JSON that is safe to embed in a `<script>` element.
    static func scriptLiteral(_ object: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    static func attributeEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // The widget runs in invisible mode: `execute()` shows a challenge only when one is needed.
    // Results come from callbacks, because the promise returned by `execute()` resolves even on errors.
    private static let template = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
    <style>html, body { margin: 0; padding: 0; background: transparent; min-height: 100%; }</style>
    <script>
    (function () {
      var settings = __SETTINGS__;
      var widgetId = null;
      var executed = false;
      function post(type, payload) {
        try {
          window.webkit.messageHandlers.__HANDLER__.postMessage({ type: type, payload: payload === undefined ? null : payload });
        } catch (e) {}
      }
      function execute() {
        if (executed || widgetId === null) { return; }
        executed = true;
        try {
          var result = window.arcaptcha.execute(widgetId);
          if (result && typeof result.catch === "function") { result.catch(function () {}); }
        } catch (e) {
          post("error", { code: 401, message: "unknown-error:" + e });
        }
      }
      function render() {
        try {
          settings.size = "invisible";
          settings.callback = function (token) { post("token", token); };
          settings.error_callback = function (error) { post("error", error || null); };
          settings.expired_callback = function () { post("expired"); };
          settings.chlexpired_callback = function () { post("challengeExpired"); };
          settings.blocked_callback = function () { post("blocked"); };
          settings.opened_callback = function () { post("opened"); };
          settings.closed_callback = function () { post("closed"); };
          settings.rendered_callback = function () { post("rendered"); setTimeout(execute, 0); };
          widgetId = window.arcaptcha.render("#arcaptcha-container", settings);
          post("ready", String(widgetId));
          setTimeout(execute, 3000);
        } catch (e) {
          post("error", { code: 401, message: "unknown-error:" + e });
        }
      }
      var attempts = 0;
      var timer = setInterval(function () {
        if (window.arcaptcha && typeof window.arcaptcha.render === "function") {
          clearInterval(timer);
          render();
        } else if (++attempts > 600) {
          clearInterval(timer);
          post("error", { code: 102, message: "create-network-error:widget-script-unavailable" });
        }
      }, 50);
      window.__arcaptchaScriptFailed = function () {
        clearInterval(timer);
        post("error", { code: 102, message: "create-network-error:widget-script-failed" });
      };
    })();
    </script>
    <script src="__SCRIPT_URL__" async defer onerror="window.__arcaptchaScriptFailed()"></script>
    </head>
    <body><div id="arcaptcha-container"></div></body>
    </html>
    """
}

/// A message posted by the widget page.
enum WebBridgeMessage: Equatable {
    case ready
    case rendered
    case token(String)
    case error(code: Int, message: String)
    case opened
    case closed
    case blocked
    case expired
    case challengeExpired

    init?(body: Any) {
        guard let dictionary = body as? [String: Any], let type = dictionary["type"] as? String else { return nil }
        let payload = dictionary["payload"]
        switch type {
        case "ready": self = .ready
        case "rendered": self = .rendered
        case "token":
            guard let token = payload as? String, !token.isEmpty else { return nil }
            self = .token(token)
        case "error":
            if let error = payload as? [String: Any] {
                let code = (error["code"] as? NSNumber)?.intValue ?? Int(error["code"] as? String ?? "") ?? 401
                self = .error(code: code, message: error["message"] as? String ?? "")
            } else {
                self = .error(code: 401, message: payload as? String ?? "unknown-error")
            }
        case "opened": self = .opened
        case "closed": self = .closed
        case "blocked": self = .blocked
        case "expired": self = .expired
        case "challengeExpired": self = .challengeExpired
        default: return nil
        }
    }
}
