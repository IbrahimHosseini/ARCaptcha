import Foundation
import Testing
@testable import ARCaptcha

/// Serves canned responses for requests made through ``StubURLProtocol/session``.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)
    nonisolated(unsafe) static var handler: Handler?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset(_ handler: @escaping Handler) {
        self.handler = handler
        requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var recorded = request
        if recorded.httpBody == nil, let stream = request.httpBodyStream {
            recorded.httpBody = Data(reading: stream)
        }
        Self.requests.append(recorded)
        do {
            let (status, data) = try Self.handler!(recorded)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension Data {
    init(reading stream: InputStream) {
        self.init()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            append(buffer, count: count)
        }
    }
}

@Suite(.serialized)
struct NativeAPIClientTests {
    private let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")!

    private func client() -> NativeAPIClient {
        NativeAPIClient(configuration: ARCaptchaConfiguration(siteKey: "site", domain: "example.com"), session: StubURLProtocol.session)
    }

    @Test func createsPuzzleAndDownloadsImages() async throws {
        let png = png
        StubURLProtocol.reset { request in
            if request.url!.path.hasSuffix("/arcaptcha/api/create") {
                return (201, Data(#"{"status":"OK","captcha_type":"puzzle","content":{"challenge_id":"c1","site_key":"site","puzzle_background":"bg","puzzle_piece":"pc","y":80}}"#.utf8))
            }
            return (200, png)
        }
        let outcome = try await client().createChallenge(.puzzle)
        #expect(outcome == .challenge(NativeChallengePayload(id: "c1", kind: .puzzle(background: png, piece: png, pieceY: 80))))
        let paths = StubURLProtocol.requests.map(\.url!.path)
        #expect(paths.contains("/arcaptcha/api/puzzles/site/:original_image_id/bg"))
        #expect(paths.contains("/arcaptcha/api/puzzles/site/:original_image_id/pc"))
        let body = try #require(StubURLProtocol.requests.first?.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["captcha_type"] as? String == "puzzle")
    }

    @Test func createsImageSelectionInOrder() async throws {
        let png = png
        StubURLProtocol.reset { request in
            if request.url!.path.hasSuffix("/arcaptcha/api/create") {
                return (201, Data(#"{"captcha_type":"question","content":{"challenge_id":"c2","site_key":"site","category":"cars","image_urls":["a","b","c"]}}"#.utf8))
            }
            return (200, png + Data(request.url!.lastPathComponent.utf8))
        }
        let outcome = try await client().createChallenge(.imageSelection)
        let expectedImages = ["a", "b", "c"].map { png + Data($0.utf8) }
        #expect(outcome == .challenge(NativeChallengePayload(id: "c2", kind: .imageSelection(category: "cars", images: expectedImages))))
    }

    @Test func createsAudioChallengeFromVoiceEndpoint() async throws {
        StubURLProtocol.reset { request in
            #expect(request.url!.path == "/arcaptcha/api/create/voice")
            return (201, Data(#"{"captcha_type":"voice_question","content":{"challenge_id":"c3","site_key":"site","path":"clip","lang":"fa"}}"#.utf8))
        }
        let outcome = try await client().createChallenge(.audio)
        #expect(outcome == .challenge(NativeChallengePayload(id: "c3", kind: .audio(url: URL(string: "https://android-api.arcaptcha.ir/arcaptcha/api/voices/clip")!))))
    }

    @Test func cookieChallengePassesWithoutUserInput() async throws {
        StubURLProtocol.reset { _ in
            (201, Data(#"{"captcha_type":"cookie","content":{"challenge_id":"trusted","site_key":"site"}}"#.utf8))
        }
        #expect(try await client().createChallenge(.imageSelection) == .passed(token: "trusted"))
    }

    @Test func unregisteredDomainIsACreateServerError() async {
        StubURLProtocol.reset { _ in
            (403, Data(#"{"status":403,"message":"Requested Domain is not registered for this site key"}"#.utf8))
        }
        await #expect(throws: ARCaptchaError(code: .createServerError, message: "403-Requested Domain is not registered for this site key")) {
            try await client().createChallenge(.puzzle)
        }
    }

    @Test func offlineIsACreateNetworkError() async throws {
        StubURLProtocol.reset { _ in throw URLError(.notConnectedToInternet) }
        let error = try await #require(throws: ARCaptchaError.self) { try await client().createChallenge(.puzzle) }
        #expect(error.code == .createNetworkError)
    }

    @Test(arguments: [
        (200, #"{"success":true}"#, AnswerOutcome.correct),
        (200, #"{"success":false}"#, AnswerOutcome.incorrect),
        (404, #"{"status":404,"message":"Challenge not exist"}"#, AnswerOutcome.expired),
    ])
    func answerOutcomes(status: Int, body: String, expected: AnswerOutcome) async throws {
        StubURLProtocol.reset { _ in (status, Data(body.utf8)) }
        #expect(try await client().submit(.audio("1234"), challengeID: "c1") == expected)
    }

    @Test func answerServerError() async throws {
        StubURLProtocol.reset { _ in (500, Data(#"{"status":500,"message":"Server error"}"#.utf8)) }
        let error = try await #require(throws: ARCaptchaError.self) { try await client().submit(.audio("1"), challengeID: "c1") }
        #expect(error.code == .answerServerError)
    }

    @Test func answerNetworkError() async throws {
        StubURLProtocol.reset { _ in throw URLError(.timedOut) }
        let error = try await #require(throws: ARCaptchaError.self) { try await client().submit(.audio("1"), challengeID: "c1") }
        #expect(error.code == .answerNetworkError)
    }
}
