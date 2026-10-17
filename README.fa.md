<div dir="rtl">

# SDK آرکپچا برای iOS

با [آرکپچا](https://arcaptcha.co) از صفحه‌های ثبت‌نام، ورود و ارسال کد تأیید اپ iOS خود در برابر ربات‌ها محافظت کنید.

[English](README.md)

- **دو روش نمایش چالش:** ویجت رسمی وب آرکپچا داخل `WKWebView`، یا چالش‌های کاملاً بومی با SwiftUI (انتخاب تصویر، پازل کشویی، صوتی).
- **سه حالت استفاده:** پنجره‌ی مودال، بررسی نامرئی که فقط در صورت نیاز چالش نشان می‌دهد، یا چالش جاسازی‌شده در صفحه‌ی خودتان.
- **پشتیبانی از SwiftUI و UIKit**، با async/await و completion handler.
- **فارسی و انگلیسی** با چیدمان راست‌به‌چپ، حالت تاریک، Dynamic Type و VoiceOver.
- **ظاهر قابل تنظیم** برای رابط بومی: رنگ، فونت، گردی گوشه‌ها و متن‌ها.
- بدون وابستگی به کتابخانه‌ی دیگر، همراه با Privacy Manifest.

## پیش‌نیازها

- iOS 15 یا بالاتر
- Xcode 16 یا بالاتر (Swift 6)
- یک site key از [داشبورد آرکپچا](https://dashboard.arcaptcha.co) و دامنه‌ای که برای آن ثبت شده است

## نصب

با Swift Package Manager اضافه کنید. در Xcode از منوی **File › Add Package Dependencies…** آدرس مخزن را وارد کنید، یا در `Package.swift`:

<div dir="ltr">

```swift
.package(url: "https://github.com/arcaptcha/arcaptcha-ios-sdk", from: "1.0.0")
```

</div>

## شروع سریع

<div dir="ltr">

```swift
import ARCaptcha

let captcha = ARCaptcha(siteKey: "YOUR_SITE_KEY", domain: "example.com")

do {
    let token = try await captcha.verify()
    try await api.signUp(email: email, captchaToken: token.value)
} catch let error as ARCaptchaError where error.code == .cancelled {
    // کاربر چالش را بست.
}
```

</div>

`verify()` چالش را در پنجره‌ای جدا روی اپ نشان می‌دهد، پس از هر صفحه‌ای قابل فراخوانی است.

### تأیید توکن در سرور

توکن را به بک‌اند خود بفرستید و آنجا با **secret key** بررسی کنید. secret key هرگز نباید داخل اپ باشد.

<div dir="ltr">

```http
POST https://api.arcaptcha.co/arcaptcha/api/verify
Content-Type: application/json

{ "challenge_id": "<token.value>", "site_key": "YOUR_SITE_KEY", "secret_key": "YOUR_SECRET_KEY" }
```

</div>

فقط وقتی درخواست را بپذیرید که پاسخ شامل `"success": true` باشد. هر توکن فقط یک بار و برای مدت کوتاهی قابل تأیید است.

## حالت‌های نمایش

### مودال یا نامرئی

<div dir="ltr">

```swift
let token = try await captcha.verify(presentation: .modal)      // بلافاصله صفحه را تیره می‌کند
let token = try await captcha.verify(presentation: .invisible)  // فقط در صورت نیاز چالش نشان می‌دهد
```

</div>

در SwiftUI:

<div dir="ltr">

```swift
Button("ارسال کد") { showsCaptcha = true }
    .arcaptcha(isPresented: $showsCaptcha, configuration: configuration) { result in
        if case let .success(token) = result { sendCode(captchaToken: token.value) }
    }
```

</div>

### چک‌باکس «من ربات نیستم» در فرم

<div dir="ltr">

```swift
@State private var token: ARCaptchaToken?

ARCaptchaCheckbox(configuration: configuration, token: $token)
Button("ثبت‌نام") { signUp(captchaToken: token!.value); token = nil }
    .disabled(token == nil)
```

</div>

نسخه‌ی UIKit آن `ARCaptchaCheckboxView` است.

### چالش جاسازی‌شده در صفحه

مثل کانتینرهای SDK اندروید، چالش بومی می‌تواند داخل صفحه‌ی شما قرار بگیرد:

<div dir="ltr">

```swift
ARCaptchaChallengeView(configuration: configuration) { token in
    self.token = token
}
```

</div>

نسخه‌ی UIKit آن `ARCaptchaChallengeViewController` است.

## تنظیمات

<div dir="ltr">

```swift
var configuration = ARCaptchaConfiguration(siteKey: "YOUR_SITE_KEY", domain: "example.com")
configuration.renderer = .native      // .web (پیش‌فرض) یا .native
configuration.language = .persian     // .persian (پیش‌فرض) یا .english
configuration.theme = .automatic      // .automatic، .light یا .dark

var appearance = ARCaptchaAppearance.default
appearance.accentColor = .systemTeal
appearance.fontName = "Vazirmatn-Regular"
configuration.appearance = appearance
```

</div>

| روش نمایش | وب | بومی |
| --- | --- | --- |
| ظاهر | ویجت رسمی آرکپچا | SwiftUI، کاملاً قابل تنظیم |
| انواع چالش | همه‌ی انواع | انتخاب تصویر، پازل، صوتی |
| تشخیص ربات | بررسی‌های کامل مرورگر | فقط بر اساس حل چالش |
| جاسازی در صفحه | خیر | بله |

جدول کامل تنظیمات، رویدادها و کدهای خطا در [README انگلیسی](README.md) آمده است. کدهای خطای 101 تا 401 همان کدهای ویجت وب و SDK اندروید هستند.

## اپ نمونه

پروژه‌ی `Examples/ARCaptchaDemo/ARCaptchaDemo.xcodeproj` را باز و اجرا کنید و site key و دامنه را وارد کنید. برای توسعه، دامنه‌ی `localhost` را در داشبورد برای site key ثبت کنید.

## مجوز

MIT. فایل [LICENSE](LICENSE) را ببینید.

</div>
