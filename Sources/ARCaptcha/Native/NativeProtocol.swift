import CoreGraphics
import CryptoKit
import Foundation

// Wire format of ARCaptcha's mobile API, as used by the official native Android SDK
// (github.com/arcaptcha/arcaptcha-native-android-sdk). Answer fields follow the web widget.

enum NativeProtocol {
    static let originalPuzzleSize = CGSize(width: 260, height: 160)
    /// Signal fields the Android SDK sends with fixed values; the API expects them to be present.
    static let placeholderFingerprint = "testfp"

    static func requestedType(for type: ARCaptchaChallengeType) -> String {
        switch type {
        case .imageSelection, .audio: "question"
        case .puzzle: "puzzle"
        }
    }
}

struct CreateChallengeRequest: Encodable {
    let siteKey: String
    let domain: String
    let captchaType: String
    let bowmanID = ""
    let components = Components()
    let fingerprint = ""
    let referer = ""
    let systemTime = ""

    struct Components: Encodable {
        let botD = Signal(value: "vb1", key: "kb1")
        let fingerprintComponents = Signal(value: "vc1", key: "kc1")
        let mouseTracker = Signal(value: "vm1", key: "km1")
        let timeTaking = 5000
    }

    struct Signal: Encodable {
        let value: String
        let key: String

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: DynamicKey.self)
            try container.encode(value, forKey: DynamicKey(key))
        }
    }

    enum CodingKeys: String, CodingKey {
        case siteKey = "site_key", domain, captchaType = "captcha_type", bowmanID = "bowman_id"
        case components, fingerprint = "fp", referer, systemTime = "system_time"
    }
}

struct DynamicKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

struct CreateChallengeResponse: Decodable {
    let captchaType: String?
    let content: Content?

    struct Content: Decodable {
        let challengeID: String?
        let category: String?
        let imageURLs: [String]?
        let puzzleBackground: String?
        let puzzlePiece: String?
        let y: Double?
        let path: String?
        let lang: String?

        enum CodingKeys: String, CodingKey {
            case challengeID = "challenge_id", category, imageURLs = "image_urls"
            case puzzleBackground = "puzzle_background", puzzlePiece = "puzzle_piece", y, path, lang
        }
    }

    enum CodingKeys: String, CodingKey {
        case captchaType = "captcha_type", content
    }
}

struct APIErrorResponse: Decodable {
    let status: Int?
    let message: String?
}

struct AnswerResponse: Decodable {
    let success: Bool
}

/// A user's answer, ready to be sent.
enum NativeAnswer: Equatable, Sendable {
    /// `selection[i]` tells whether image `i` was picked. `intervals` holds the milliseconds between picks.
    case imageSelection(selection: [Bool], intervals: [Int])
    /// `offset` is the piece's x position in the 260-point-wide original image.
    case puzzle(offset: Int, speed: Double, duration: Int)
    case audio(String)
}

struct AnswerRequest: Encodable {
    let siteKey: String
    let domain: String
    let challengeID: String
    let answer: NativeAnswer

    enum CodingKeys: String, CodingKey {
        case siteKey = "site_key", domain, challengeID = "challenge_id", answers, fingerprint = "fp"
        case timeBetweenSelections = "time_between_selections", dragDrop = "drag_drop", dragDropTime = "drag_drop_time"
    }

    struct SelectionAnswer: Encodable {
        let a: String
        let m: [Bool]
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(siteKey, forKey: .siteKey)
        try container.encode(domain, forKey: .domain)
        try container.encode(challengeID, forKey: .challengeID)
        switch answer {
        case let .imageSelection(selection, intervals):
            try container.encode(SelectionAnswer(a: AnswerEncoding.selectionHash(selection), m: selection), forKey: .answers)
            try container.encode(intervals, forKey: .timeBetweenSelections)
            try container.encode(NativeProtocol.placeholderFingerprint, forKey: .fingerprint)
        case let .puzzle(offset, speed, duration):
            try container.encode(offset, forKey: .answers)
            try container.encode(speed, forKey: .dragDrop)
            try container.encode(duration, forKey: .dragDropTime)
        case let .audio(text):
            try container.encode(text, forKey: .answers)
        }
    }
}

enum AnswerEncoding {
    /// SHA-1 hex digest of the selection read as a binary number, written in decimal.
    /// `[true, false, true]` is `0b101`, so the digest of `"5"`.
    static func selectionHash(_ selection: [Bool]) -> String {
        let value = selection.reduce(0) { ($0 << 1) | ($1 ? 1 : 0) }
        let digest = Insecure.SHA1.hash(data: Data(String(value).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Milliseconds between consecutive timestamps.
    static func intervals(between timestamps: [Date]) -> [Int] {
        zip(timestamps, timestamps.dropFirst()).map { Int(($1.timeIntervalSince($0) * 1000).rounded()) }
    }

    /// Distance per millisecond, rounded to two decimals like the web widget.
    static func dragSpeed(distance: Double, milliseconds: Int) -> Double {
        guard milliseconds > 0 else { return 0 }
        return (distance / Double(milliseconds) * 100).rounded() / 100
    }
}
