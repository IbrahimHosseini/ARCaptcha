# Changelog

## 1.0.0

First release.

- `ARCaptcha.verify(presentation:in:)` with modal and invisible presentation, async/await and completion handler.
- Web renderer: ARCaptcha's official widget in a `WKWebView`, bridged through its callbacks.
- Native renderer: SwiftUI image-selection, slide-puzzle and audio challenges over ARCaptcha's mobile API.
- `ARCaptchaCheckbox` (SwiftUI) and `ARCaptchaCheckboxView` (UIKit).
- `ARCaptchaChallengeView` (SwiftUI) and `ARCaptchaChallengeViewController` (UIKit) for embedded challenges.
- `.arcaptcha(isPresented:configuration:)` view modifier.
- Persian and English texts, right-to-left layout, Dark Mode, Dynamic Type, VoiceOver labels.
- `ARCaptchaAppearance` and `ARCaptchaStrings` for theming.
- Privacy manifest.
