import Foundation

/// The texts of the SDK's own UI. Start from ``persian`` or ``english`` and change what you need.
///
/// Texts drawn by the web widget come from ARCaptcha and follow ``ARCaptchaConfiguration/language``.
public struct ARCaptchaStrings: Hashable, Sendable {
    public var checkboxTitle: String
    public var checkboxVerified: String
    public var checkboxFailed: String
    /// `%@` is replaced with the category, for example "cars".
    public var imageSelectionInstruction: String
    public var puzzleInstruction: String
    public var audioInstruction: String
    public var audioPlaceholder: String
    public var imageSelectionHelp: String
    public var puzzleHelp: String
    public var audioHelp: String
    public var confirm: String
    public var refresh: String
    public var close: String
    public var help: String
    public var ok: String
    public var switchToAudio: String
    public var switchToVisual: String
    public var playAudio: String
    public var stopAudio: String
    public var solved: String
    public var wrongAnswer: String
    public var loading: String
    public var loadFailed: String
    public var retry: String
    /// `%1$d` is the image's position and `%2$d` the number of images.
    public var imageAccessibilityLabel: String
    public var puzzleSliderAccessibilityLabel: String
    public var brandName: String

    public init(
        checkboxTitle: String,
        checkboxVerified: String,
        checkboxFailed: String,
        imageSelectionInstruction: String,
        puzzleInstruction: String,
        audioInstruction: String,
        audioPlaceholder: String,
        imageSelectionHelp: String,
        puzzleHelp: String,
        audioHelp: String,
        confirm: String,
        refresh: String,
        close: String,
        help: String,
        ok: String,
        switchToAudio: String,
        switchToVisual: String,
        playAudio: String,
        stopAudio: String,
        solved: String,
        wrongAnswer: String,
        loading: String,
        loadFailed: String,
        retry: String,
        imageAccessibilityLabel: String,
        puzzleSliderAccessibilityLabel: String,
        brandName: String = "ARCaptcha"
    ) {
        self.checkboxTitle = checkboxTitle
        self.checkboxVerified = checkboxVerified
        self.checkboxFailed = checkboxFailed
        self.imageSelectionInstruction = imageSelectionInstruction
        self.puzzleInstruction = puzzleInstruction
        self.audioInstruction = audioInstruction
        self.audioPlaceholder = audioPlaceholder
        self.imageSelectionHelp = imageSelectionHelp
        self.puzzleHelp = puzzleHelp
        self.audioHelp = audioHelp
        self.confirm = confirm
        self.refresh = refresh
        self.close = close
        self.help = help
        self.ok = ok
        self.switchToAudio = switchToAudio
        self.switchToVisual = switchToVisual
        self.playAudio = playAudio
        self.stopAudio = stopAudio
        self.solved = solved
        self.wrongAnswer = wrongAnswer
        self.loading = loading
        self.loadFailed = loadFailed
        self.retry = retry
        self.imageAccessibilityLabel = imageAccessibilityLabel
        self.puzzleSliderAccessibilityLabel = puzzleSliderAccessibilityLabel
        self.brandName = brandName
    }

    public static let persian = ARCaptchaStrings(
        checkboxTitle: "من ربات نیستم",
        checkboxVerified: "تأیید شد",
        checkboxFailed: "بررسی انجام نشد. دوباره تلاش کنید.",
        imageSelectionInstruction: "تصاویر شامل %@ را انتخاب کنید.",
        puzzleInstruction: "با کشیدن فلش، پازل را درست کنید",
        audioInstruction: "چیزی که می‌شنوید را وارد کنید",
        audioPlaceholder: "پاسخ",
        imageSelectionHelp: "هر عکسی را که شبیه یا مطابق توضیحات داده شده است انتخاب کنید، سپس دکمه تأیید را بزنید.",
        puzzleHelp: "اسلایدر را بکشید تا قطعه پازل در جای خالی‌اش قرار بگیرد.",
        audioHelp: "صدا را پخش کنید و چیزی را که می‌شنوید در کادر بنویسید.",
        confirm: "تأیید",
        refresh: "چالش جدید",
        close: "بستن",
        help: "راهنما",
        ok: "باشه",
        switchToAudio: "کپچای صوتی",
        switchToVisual: "کپچای تصویری",
        playAudio: "پخش صدا",
        stopAudio: "توقف صدا",
        solved: "چالش با موفقیت حل شد",
        wrongAnswer: "پاسخ درست نبود، دوباره تلاش کنید",
        loading: "در حال بارگذاری",
        loadFailed: "بارگذاری چالش انجام نشد.",
        retry: "تلاش دوباره",
        imageAccessibilityLabel: "تصویر %1$d از %2$d",
        puzzleSliderAccessibilityLabel: "اسلایدر پازل",
        brandName: "آرکپچا"
    )

    public static let english = ARCaptchaStrings(
        checkboxTitle: "I'm not a robot",
        checkboxVerified: "Verified",
        checkboxFailed: "Verification failed. Try again.",
        imageSelectionInstruction: "Select all images with %@.",
        puzzleInstruction: "Drag the arrow to complete the puzzle",
        audioInstruction: "Type what you hear",
        audioPlaceholder: "Answer",
        imageSelectionHelp: "Select every image that matches the description, then tap Confirm.",
        puzzleHelp: "Drag the slider until the puzzle piece fits into its slot.",
        audioHelp: "Play the audio and type what you hear.",
        confirm: "Confirm",
        refresh: "New challenge",
        close: "Close",
        help: "Help",
        ok: "OK",
        switchToAudio: "Audio challenge",
        switchToVisual: "Visual challenge",
        playAudio: "Play audio",
        stopAudio: "Stop audio",
        solved: "Challenge solved",
        wrongAnswer: "That wasn't right. Try again.",
        loading: "Loading",
        loadFailed: "The challenge couldn't be loaded.",
        retry: "Try again",
        imageAccessibilityLabel: "Image %1$d of %2$d",
        puzzleSliderAccessibilityLabel: "Puzzle slider"
    )

    public static func defaults(for language: ARCaptchaLanguage) -> ARCaptchaStrings {
        switch language {
        case .persian: .persian
        case .english: .english
        }
    }
}
