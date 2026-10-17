import SwiftUI
import UIKit

/// The look of the SDK's own UI: the native challenge, the checkbox and the overlay around challenges.
///
/// The web widget draws itself; it only takes ``ARCaptchaTheme`` and ``ARCaptchaConfiguration/WebOptions/color``.
/// Use dynamic `UIColor`s to give light and dark mode different colors.
///
/// ```swift
/// var appearance = ARCaptchaAppearance.default
/// appearance.accentColor = .systemTeal
/// appearance.cornerRadius = 8
/// appearance.fontName = "Vazirmatn-Regular"
/// configuration.appearance = appearance
/// ```
// UIColor is immutable and safe to share across threads.
public struct ARCaptchaAppearance: @unchecked Sendable {
    /// Buttons, the slider, selected images and highlighted words.
    public var accentColor: UIColor
    /// The challenge card and checkbox background.
    public var backgroundColor: UIColor
    /// Instructions and titles.
    public var primaryTextColor: UIColor
    /// Footer, hints and borders.
    public var secondaryTextColor: UIColor
    /// Text fields and the slider track.
    public var fieldBackgroundColor: UIColor
    public var successColor: UIColor
    public var errorColor: UIColor
    /// The color laid over your app while a challenge is shown.
    public var dimmingColor: UIColor
    public var cornerRadius: CGFloat
    /// The PostScript name of a font your app bundles. `nil` uses the system font.
    /// Text keeps scaling with Dynamic Type either way.
    public var fontName: String?
    /// Shows the ARCaptcha name in the footer.
    public var showsBranding: Bool

    public init(
        accentColor: UIColor = ARCaptchaAppearance.brandAccent,
        backgroundColor: UIColor = .dynamic(light: 0xFFFFFF, dark: 0x171730),
        primaryTextColor: UIColor = .dynamic(light: 0x5555AA, dark: 0xE6E6F0),
        secondaryTextColor: UIColor = .dynamic(light: 0x8E8FA8, dark: 0x9A9BB8),
        fieldBackgroundColor: UIColor = .dynamic(light: 0xF0F0F7, dark: 0x2A2A55),
        successColor: UIColor = .dynamic(light: 0x06966A, dark: 0x1FB386),
        errorColor: UIColor = .dynamic(light: 0xD93A37, dark: 0xF06461),
        dimmingColor: UIColor = UIColor.black.withAlphaComponent(0.45),
        cornerRadius: CGFloat = 16,
        fontName: String? = nil,
        showsBranding: Bool = true
    ) {
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.fieldBackgroundColor = fieldBackgroundColor
        self.successColor = successColor
        self.errorColor = errorColor
        self.dimmingColor = dimmingColor
        self.cornerRadius = cornerRadius
        self.fontName = fontName
        self.showsBranding = showsBranding
    }

    /// ARCaptcha's colors, matching the official Android SDK.
    public static let `default` = ARCaptchaAppearance()

    /// ARCaptcha's brand purple.
    public static let brandAccent = UIColor(hex: 0x978FF2)

    func font(_ style: Font.TextStyle, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName {
            return Font.custom(fontName, size: size, relativeTo: style).weight(weight)
        }
        return Font.system(style).weight(weight)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// A color that switches between two hex values with the interface style.
    public static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        let lightColor = UIColor(hex: light)
        let darkColor = UIColor(hex: dark)
        return UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor }
    }
}

extension ARCaptchaTheme {
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .automatic: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
