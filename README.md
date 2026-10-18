# ARCaptcha iOS SDK

Protect your iOS app's sign-up, login and OTP screens with [ARCaptcha](https://arcaptcha.co).

- **Two renderers**: ARCaptcha's official web widget in a `WKWebView`, or fully native SwiftUI challenges (image selection, slide puzzle, audio).
- **Three ways to show it**: a modal challenge, an invisible check that shows a challenge only when needed, or a challenge embedded in your layout.
- **SwiftUI and UIKit**, async/await and completion handlers.
- **Persian and English**, right-to-left layout, Dark Mode, Dynamic Type and VoiceOver.
- **Fully themeable** native UI: colors, fonts, corner radius, texts.
- No third-party dependencies. Ships a privacy manifest.

## Requirements

- iOS 14 or later
- Xcode 16 or later (Swift 6)
- A site key from the [ARCaptcha dashboard](https://dashboard.arcaptcha.co) and a domain registered for it

## Installation

Add the package with Swift Package Manager. In Xcode choose **File › Add Package Dependencies…** and enter `https://p-source.780.ir/ios/arcaptcha.git`, or add it to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://p-source.780.ir/ios/arcaptcha.git", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [.product(name: "ARCaptcha", package: "arcaptcha")]),
]
```

## Quick start

```swift
import ARCaptcha

let captcha = ARCaptcha(siteKey: "YOUR_SITE_KEY", domain: "example.com")

do {
    let token = try await captcha.verify()
    try await api.signUp(email: email, captchaToken: token.value)
} catch let error as ARCaptchaError where error.code == .cancelled {
    // The user closed the challenge.
} catch {
    // See "Errors" below.
}
```

`verify()` shows the challenge in its own window above your app, so you can call it from any screen, SwiftUI or UIKit.

### Verify the token on your server

The token proves nothing until your backend checks it with your **secret key**. Never put the secret key in the app.

```http
POST https://api.arcaptcha.co/arcaptcha/api/verify
Content-Type: application/json

{ "challenge_id": "<token.value>", "site_key": "YOUR_SITE_KEY", "secret_key": "YOUR_SECRET_KEY" }
```

Accept the request only when the response has `"success": true`. A token can be verified once, shortly after it is issued. ARCaptcha offers server libraries for Node.js, PHP, Python, Go, C#, Laravel and more.

## Ways to show a challenge

### Modal or invisible

```swift
// Dims the screen and shows a loading indicator right away.
let token = try await captcha.verify(presentation: .modal)

// Shows nothing unless ARCaptcha decides this user must solve a challenge.
let token = try await captcha.verify(presentation: .invisible)
```

In SwiftUI you can bind the challenge to a `Bool`:

```swift
Button("Send code") { showsCaptcha = true }
    .arcaptcha(isPresented: $showsCaptcha, configuration: configuration) { result in
        if case let .success(token) = result { sendCode(captchaToken: token.value) }
    }
```

From UIKit, with a completion handler:

```swift
captcha.verify(in: view.window?.windowScene) { result in
    switch result {
    case let .success(token): self.submit(token: token.value)
    case let .failure(error): self.show(error)
    }
}
```

### Checkbox in a form

An "I'm not a robot" box that runs an invisible check when tapped. The token is cleared when it expires. Clear it yourself after use, because a token works only once.

```swift
@State private var token: ARCaptchaToken?

var body: some View {
    Form {
        TextField("Email", text: $email)
        ARCaptchaCheckbox(configuration: configuration, token: $token)
        Button("Sign up") {
            signUp(captchaToken: token!.value)
            token = nil
        }
        .disabled(token == nil)
    }
}
```

UIKit:

```swift
let checkbox = ARCaptchaCheckboxView(configuration: configuration)
checkbox.onTokenChange = { [weak self] token in self?.signUpButton.isEnabled = token != nil }
stackView.addArrangedSubview(checkbox)
// After using the token:
checkbox.reset()
```

### Challenge embedded in your layout

Like the containers of the Android SDK, the native challenge can sit inside your screen. It always uses the native renderer.

```swift
ARCaptchaChallengeView(configuration: configuration) { token in
    self.token = token
}
```

UIKit:

```swift
let challenge = ARCaptchaChallengeViewController(configuration: configuration) { [weak self] token in
    self?.token = token
}
addChild(challenge)
stackView.addArrangedSubview(challenge.view)
challenge.didMove(toParent: self)
```

The help button shows a system alert. To show the help in your app's own alert, pass `onHelp`:

```swift
ARCaptchaChallengeView(configuration: configuration, onHelp: { help in
    showAlert(title: help.title, message: help.message, button: help.dismissTitle)
}) { token in
    self.token = token
}
```

## Configuration

```swift
var configuration = ARCaptchaConfiguration(siteKey: "YOUR_SITE_KEY", domain: "example.com")
configuration.renderer = .native          // .web (default) or .native
configuration.language = .english         // .persian (default) or .english
configuration.theme = .dark               // .automatic (default), .light or .dark
configuration.loadingTimeout = 20         // seconds before failing with .timeout
let captcha = ARCaptcha(configuration: configuration)
```

| Property | Default | Description |
| --- | --- | --- |
| `siteKey` | required | Your public site key. |
| `domain` | required | A domain registered for the site key, such as `example.com`. |
| `renderer` | `.web` | `.web` uses ARCaptcha's official widget; `.native` draws SwiftUI challenges. |
| `language` | `.persian` | `.persian` or `.english`. Persian lays out right to left. |
| `theme` | `.automatic` | `.automatic` follows the system. |
| `appearance` | ARCaptcha colors | Colors, font, corner radius and branding of the SDK's own UI. |
| `strings` | `nil` | Replaces the built-in Persian or English texts. |
| `loadingTimeout` | `30` | Seconds to wait for the challenge to appear. |
| `tokenLifetime` | `120` | Seconds a token is treated as valid. |
| `web.color` | `nil` | A color name or hex code for the web widget. |
| `web.showsErrorMessages` | `false` | Shows the web widget's own error messages. |
| `web.baseURL` | `https://<domain>/` | The origin the widget page is loaded under. |
| `web.isInspectable` | `false` | Lets Safari Web Inspector attach (iOS 16.4+). |
| `native.preferredChallenge` | `.imageSelection` | The challenge to ask for first. Dashboard settings can override it. |
| `native.allowsAudioChallenge` | `true` | Shows a button that switches to an audio challenge. |
| `native.managesAudioSession` | `true` | Plays audio challenges even in silent mode, then restores your audio session. |

### Choosing a renderer

| | Web | Native |
| --- | --- | --- |
| Look | ARCaptcha's widget | SwiftUI, fully themeable |
| Challenges | Every type ARCaptcha serves | Image selection, slide puzzle, audio |
| Bot detection | ARCaptcha's full browser checks | Challenge-based only |
| Server-side widget updates | Automatic | Need an SDK update |
| Embedding in a layout | No | Yes (`ARCaptchaChallengeView`) |

The native renderer uses ARCaptcha's mobile API, the same one as the official native Android SDK.

### Appearance

```swift
var appearance = ARCaptchaAppearance.default
appearance.accentColor = .systemTeal
appearance.backgroundColor = .secondarySystemGroupedBackground
appearance.primaryTextColor = .label
appearance.cornerRadius = 8
appearance.fontName = "Vazirmatn-Regular"   // a font your app bundles
appearance.showsBranding = false
configuration.appearance = appearance
```

Use dynamic colors, such as `.label` or `UIColor.dynamic(light:dark:)`, to give light and dark mode different colors. The web widget keeps its own look and only takes `theme` and `web.color`.

### Texts

```swift
var strings = ARCaptchaStrings.english
strings.checkboxTitle = "Confirm you're human"
configuration.strings = strings
```

## Events

```swift
captcha.onEvent = { event in
    analytics.log("captcha", String(describing: event))
}
```

| Event | When |
| --- | --- |
| `loading` | A challenge is requested. |
| `challengeLoaded(type)` | A challenge is ready. `type` is `nil` for the web renderer. |
| `challengePresented` | The challenge became visible. |
| `answerStarted` | The user started interacting. |
| `answerSubmitted` | The answer was sent. |
| `answerRejected` | The answer was wrong. A new challenge follows. |
| `challengeExpired` | The challenge expired unanswered. A new challenge follows. |
| `tokenIssued` | The user passed. |
| `tokenExpired` | A token from the checkbox or the embedded challenge expired. |
| `failed(error)` | The verification failed. |
| `closed` | The challenge UI was removed. |

## Errors

`verify` throws `ARCaptchaError`. Codes below 1000 match the ARCaptcha web widget and Android SDKs.

| Code | Name | Meaning |
| --- | --- | --- |
| 101 | `createServerError` | ARCaptcha could not create a challenge. Check the site key and that the domain is registered. |
| 102 | `createNetworkError` | No connection while loading the challenge. |
| 201 | `answerServerError` | ARCaptcha could not check the answer. |
| 202 | `answerNetworkError` | No connection while sending the answer. |
| 203 | `answerWrong` | The answer was wrong. |
| 401 | `unknown` | Anything else. |
| 1000 | `cancelled` | The user closed the challenge, or `cancel()` was called. |
| 1001 | `timeout` | The challenge did not load within `loadingTimeout`. |
| 1002 | `blocked` | ARCaptcha classified the client as a bot. |
| 1003 | `invalidConfiguration` | Empty site key or domain, or a URL given as the domain. |
| 1004 | `presentationFailed` | No foreground window scene to show the challenge in. |
| 1005 | `alreadyInProgress` | `verify` was called while another verification was running. |

## Privacy

The package includes `PrivacyInfo.xcprivacy`. It declares product interaction and diagnostic data, collected for app functionality (fraud prevention), not linked to the user and not used for tracking. The web renderer runs ARCaptcha's widget, which inspects the web view's browser environment to detect bots. Mention ARCaptcha in your privacy policy as you would any anti-abuse service.

## Demo app

`Examples/ARCaptchaDemo` shows every API: renderers, languages, themes, the checkbox, the embedded challenge and UIKit usage. Open `Examples/ARCaptchaDemo/ARCaptchaDemo.xcodeproj`, run it, and enter your site key and domain. You can also pass them as launch arguments: `-siteKey YOUR_SITE_KEY -domain example.com`.

For development, register `localhost` as a domain of your site key in the dashboard and use `localhost` as `domain`.

## Running the tests

```bash
xcodebuild test -scheme ARCaptcha -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

To work on the native UI without solving real challenges, run the mock API and point the demo at it:

```bash
python3 Tools/MockAPI/mock_server.py 8798
```

Then launch the demo with `-nativeAPIBaseURL http://127.0.0.1:8798/`. The mock serves plain-colored puzzles and image grids, logs every answer it receives, and never accepts one.

## License

MIT. See [LICENSE](LICENSE).
