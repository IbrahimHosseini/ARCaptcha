import Foundation
import Testing
@testable import ARCaptcha

struct AnswerEncodingTests {
    @Test(arguments: [
        ([true, false, true], "ac3478d69a3c81fa62e60f5c3696165a4e5e6ac4"),
        ([Bool](repeating: false, count: 9), "b6589fc6ab0dc82cf12099d1c2d40ab994e8410c"),
        ([true, false, false, false, false, false, false, false, true], "c439c60b7bf00fc6d80b76312309f8dc6107f635"),
        ([Bool](repeating: true, count: 9), "b7f5113f83376fc4334a2f305303bd99b533a5c4"),
    ])
    func selectionHashMatchesWebWidget(selection: [Bool], expected: String) {
        #expect(AnswerEncoding.selectionHash(selection) == expected)
    }

    @Test func intervalsAreMillisecondsBetweenTimestamps() {
        let start = Date(timeIntervalSince1970: 1_000)
        let stamps = [start, start.addingTimeInterval(0.25), start.addingTimeInterval(1.0), start.addingTimeInterval(1.0015)]
        #expect(AnswerEncoding.intervals(between: stamps) == [250, 750, 2])
        #expect(AnswerEncoding.intervals(between: [start]).isEmpty)
    }

    @Test func dragSpeedIsRoundedToTwoDecimals() {
        #expect(AnswerEncoding.dragSpeed(distance: 100, milliseconds: 300) == 0.33)
        #expect(AnswerEncoding.dragSpeed(distance: 100, milliseconds: 0) == 0)
    }
}

struct RequestEncodingTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func createRequestMatchesAndroidShape() throws {
        let body = try json(CreateChallengeRequest(siteKey: "key", domain: "example.com", captchaType: "puzzle"))
        #expect(body["site_key"] as? String == "key")
        #expect(body["domain"] as? String == "example.com")
        #expect(body["captcha_type"] as? String == "puzzle")
        let components = try #require(body["components"] as? [String: Any])
        #expect((components["botD"] as? [String: String]) == ["kb1": "vb1"])
        #expect((components["fingerprintComponents"] as? [String: String]) == ["kc1": "vc1"])
        #expect((components["mouseTracker"] as? [String: String]) == ["km1": "vm1"])
        #expect(components["timeTaking"] as? Int == 5000)
    }

    @Test func imageSelectionAnswer() throws {
        let request = AnswerRequest(siteKey: "key", domain: "d", challengeID: "c1", answer: .imageSelection(selection: [true, false, true], intervals: [120, 340]))
        let body = try json(request)
        #expect(body["challenge_id"] as? String == "c1")
        let answers = try #require(body["answers"] as? [String: Any])
        #expect(answers["a"] as? String == "ac3478d69a3c81fa62e60f5c3696165a4e5e6ac4")
        #expect(answers["m"] as? [Bool] == [true, false, true])
        #expect(body["time_between_selections"] as? [Int] == [120, 340])
        #expect(body["fp"] as? String == NativeProtocol.placeholderFingerprint)
    }

    @Test func puzzleAnswer() throws {
        let body = try json(AnswerRequest(siteKey: "key", domain: "d", challengeID: "c1", answer: .puzzle(offset: 64, speed: 0.21, duration: 900)))
        #expect(body["answers"] as? Int == 64)
        #expect(body["drag_drop"] as? Double == 0.21)
        #expect(body["drag_drop_time"] as? Int == 900)
    }

    @Test func audioAnswer() throws {
        let body = try json(AnswerRequest(siteKey: "key", domain: "d", challengeID: "c1", answer: .audio("۴۲۷")))
        #expect(body["answers"] as? String == "۴۲۷")
        #expect(body["time_between_selections"] == nil)
    }
}
