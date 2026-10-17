import Foundation

/// Everything ARCaptcha needs to know to show a challenge.
///
/// ```swift
/// var configuration = ARCaptchaConfiguration(siteKey: "YOUR_SITE_KEY", domain: "example.com")
/// configuration.renderer = .native
/// configuration.language = .english
/// ```
public struct ARCaptchaConfiguration: Sendable {
    /// Your public site key from the ARCaptcha dashboard. Never put the secret key in an app.
    public var siteKey: String
    /// A domain registered for the site key in the ARCaptcha dashboard.
    public var domain: String
    public var renderer: Renderer
    public var language: ARCaptchaLanguage
    public var theme: ARCaptchaTheme
    /// Colors, fonts and shapes of the SDK's own UI: the native challenge, the checkbox and the overlay.
    public var appearance: ARCaptchaAppearance
    /// Overrides the built-in Persian or English texts. `nil` uses the defaults for ``language``.
    public var strings: ARCaptchaStrings?
    public var web: WebOptions
    public var native: NativeOptions
    /// How long to wait for the challenge to appear before failing with ``ARCaptchaError/Code/timeout``.
    /// It does not limit the time the user spends solving.
    public var loadingTimeout: TimeInterval
    /// How long an issued token is treated as valid. ARCaptcha challenges expire after two minutes.
    public var tokenLifetime: TimeInterval

    public init(
        siteKey: String,
        domain: String,
        renderer: Renderer = .web,
        language: ARCaptchaLanguage = .persian,
        theme: ARCaptchaTheme = .automatic
    ) {
        self.siteKey = siteKey
        self.domain = domain
        self.renderer = renderer
        self.language = language
        self.theme = theme
        self.appearance = .default
        self.strings = nil
        self.web = WebOptions()
        self.native = NativeOptions()
        self.loadingTimeout = 30
        self.tokenLifetime = 120
    }

    /// How the challenge is drawn.
    public enum Renderer: String, Hashable, Sendable, CaseIterable {
        /// ARCaptcha's official web widget in a `WKWebView`. It supports every challenge type,
        /// runs ARCaptcha's full bot detection, and follows server-side widget updates.
        case web
        /// SwiftUI views that talk to ARCaptcha's mobile API directly. It looks native and can be
        /// fully themed with ``ARCaptchaAppearance``.
        case native
    }

    public struct WebOptions: Sendable {
        /// The ARCaptcha widget script.
        public var scriptURL: URL
        /// The origin the widget page is loaded under. `nil` uses `https://<domain>/`.
        public var baseURL: URL?
        /// A color name or hex code applied to the widget's colored elements.
        public var color: String?
        /// Shows the widget's own error messages.
        public var showsErrorMessages: Bool
        /// Allows Safari Web Inspector to attach on iOS 16.4 and later. Leave it off in release builds.
        public var isInspectable: Bool

        public init(
            scriptURL: URL = URL(string: "https://widget.arcaptcha.ir/1/api.js")!,
            baseURL: URL? = nil,
            color: String? = nil,
            showsErrorMessages: Bool = false,
            isInspectable: Bool = false
        ) {
            self.scriptURL = scriptURL
            self.baseURL = baseURL
            self.color = color
            self.showsErrorMessages = showsErrorMessages
            self.isInspectable = isInspectable
        }
    }

    public struct NativeOptions: Sendable {
        /// The ARCaptcha mobile API.
        public var apiBaseURL: URL
        /// The challenge to ask for first. The site's settings in the dashboard can override it.
        public var preferredChallenge: ARCaptchaChallengeType
        /// Shows a button that switches to an audio challenge, for users who cannot solve visual ones.
        public var allowsAudioChallenge: Bool
        /// Switches the audio session to playback while an audio challenge plays, so it is heard even
        /// in silent mode, and restores the previous category afterwards.
        public var managesAudioSession: Bool

        public init(
            apiBaseURL: URL = URL(string: "https://android-api.arcaptcha.ir/")!,
            preferredChallenge: ARCaptchaChallengeType = .imageSelection,
            allowsAudioChallenge: Bool = true,
            managesAudioSession: Bool = true
        ) {
            self.apiBaseURL = apiBaseURL
            self.preferredChallenge = preferredChallenge
            self.allowsAudioChallenge = allowsAudioChallenge
            self.managesAudioSession = managesAudioSession
        }
    }

    var resolvedStrings: ARCaptchaStrings { strings ?? .defaults(for: language) }

    func validate() throws {
        if siteKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ARCaptchaError(code: .invalidConfiguration, message: "The site key is empty.")
        }
        if domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ARCaptchaError(code: .invalidConfiguration, message: "The domain is empty.")
        }
        if domain.contains("://") || domain.contains("/") {
            throw ARCaptchaError(code: .invalidConfiguration, message: "The domain must be a host name such as example.com, not a URL.")
        }
    }
}

public enum ARCaptchaLanguage: String, Hashable, Sendable, CaseIterable {
    case persian = "fa"
    case english = "en"

    var isRightToLeft: Bool { self == .persian }
}

public enum ARCaptchaTheme: String, Hashable, Sendable, CaseIterable {
    /// Follows the system's light or dark mode.
    case automatic
    case light
    case dark
}
