import Foundation
import Testing
@testable import ARCaptcha

struct WebWidgetDocumentTests {
    @Test func loadsScriptWithDomainAndUsesDomainAsOrigin() {
        let document = WebWidgetDocument(configuration: ARCaptchaConfiguration(siteKey: "abc", domain: "example.com"), isDark: false)
        #expect(document.html.contains(#"src="https://widget.arcaptcha.ir/1/api.js?domain=example.com""#))
        #expect(document.baseURL == URL(string: "https://example.com/"))
    }

    @Test func passesWidgetSettings() {
        var configuration = ARCaptchaConfiguration(siteKey: "abc", domain: "example.com", language: .english, theme: .automatic)
        configuration.web.color = "#FF0000"
        configuration.web.showsErrorMessages = true
        let document = WebWidgetDocument(configuration: configuration, isDark: true)
        #expect(document.html.contains(##""color":"#FF0000""##))
        #expect(document.html.contains(#""error_print":1"#))
        #expect(document.html.contains(#""lang":"en""#))
        #expect(document.html.contains(#""site_key":"abc""#))
        #expect(document.html.contains(#""theme":"dark""#))
    }

    @Test func explicitThemeWinsOverSystem() {
        let configuration = ARCaptchaConfiguration(siteKey: "abc", domain: "example.com", theme: .light)
        #expect(WebWidgetDocument(configuration: configuration, isDark: true).html.contains(#""theme":"light""#))
    }

    @Test func siteKeyCannotBreakOutOfTheScript() {
        let document = WebWidgetDocument(configuration: ARCaptchaConfiguration(siteKey: "</script><script>alert(1)</script>", domain: "example.com"), isDark: false)
        #expect(!document.html.contains("</script><script>alert(1)"))
        #expect(document.html.contains(#"<\/script>"#) || document.html.contains(#"</script>"#))
    }

    @Test func customBaseURL() {
        var configuration = ARCaptchaConfiguration(siteKey: "abc", domain: "example.com")
        configuration.web.baseURL = URL(string: "https://app.example.com/")
        #expect(WebWidgetDocument(configuration: configuration, isDark: false).baseURL == URL(string: "https://app.example.com/"))
    }
}

struct WebBridgeMessageTests {
    @Test func parsesMessages() {
        #expect(WebBridgeMessage(body: ["type": "token", "payload": "t1"]) == .token("t1"))
        #expect(WebBridgeMessage(body: ["type": "opened", "payload": NSNull()]) == .opened)
        #expect(WebBridgeMessage(body: ["type": "closed"]) == .closed)
        #expect(WebBridgeMessage(body: ["type": "blocked"]) == .blocked)
        #expect(WebBridgeMessage(body: ["type": "challengeExpired"]) == .challengeExpired)
        #expect(WebBridgeMessage(body: ["type": "error", "payload": ["code": NSNumber(value: 101), "message": "create-server-error:404"]])
            == .error(code: 101, message: "create-server-error:404"))
        #expect(WebBridgeMessage(body: ["type": "error", "payload": "boom"]) == .error(code: 401, message: "boom"))
    }

    @Test func rejectsMalformedMessages() {
        #expect(WebBridgeMessage(body: "token") == nil)
        #expect(WebBridgeMessage(body: ["type": "token", "payload": ""]) == nil)
        #expect(WebBridgeMessage(body: ["type": "unknown"]) == nil)
    }
}

@MainActor
struct WebChallengeRendererTests {
    private func run(_ messages: [WebBridgeMessage]) -> [String] {
        let renderer = WebChallengeRenderer(configuration: ARCaptchaConfiguration(siteKey: "abc", domain: "example.com"))
        var outputs: [String] = []
        renderer.output = { output in
            switch output {
            case let .event(event): outputs.append("event:\(event)")
            case .needsPresentation: outputs.append("present")
            case let .solved(token): outputs.append("solved:\(token.value)")
            case let .failed(error): outputs.append("failed:\(error.code.rawValue)")
            case .dismissed: outputs.append("dismissed")
            }
        }
        messages.forEach(renderer.handle)
        renderer.stop()
        return outputs
    }

    @Test func passesWithoutChallenge() {
        #expect(run([.ready, .rendered, .token("t1"), .closed]) == ["solved:t1"])
    }

    @Test func presentsThenSolves() {
        #expect(run([.rendered, .opened, .token("t1")]) == ["event:challengeLoaded(nil)", "present", "solved:t1"])
    }

    @Test func errorBeforeChallengeFailsAtOnce() {
        #expect(run([.error(code: 101, message: "create-server-error:404"), .closed]) == ["failed:101"])
    }

    @Test func errorInsideChallengeFailsWhenClosed() {
        #expect(run([.opened, .error(code: 201, message: "x"), .closed]) == ["event:challengeLoaded(nil)", "present", "failed:201"])
    }

    @Test func wrongAnswerKeepsTheChallengeOpen() {
        #expect(run([.opened, .error(code: 203, message: "answer-wrong-error"), .opened, .token("t2")])
            == ["event:challengeLoaded(nil)", "present", "event:answerRejected", "event:challengeLoaded(nil)", "present", "solved:t2"])
    }

    @Test func closingIsACancellation() {
        #expect(run([.opened, .closed]) == ["event:challengeLoaded(nil)", "present", "dismissed"])
    }

    @Test func blockedClient() {
        #expect(run([.blocked]) == ["failed:1002"])
    }
}

struct ConfigurationTests {
    @Test func rejectsUnusableConfigurations() {
        #expect(throws: ARCaptchaError.self) { try ARCaptchaConfiguration(siteKey: " ", domain: "example.com").validate() }
        #expect(throws: ARCaptchaError.self) { try ARCaptchaConfiguration(siteKey: "abc", domain: "").validate() }
        #expect(throws: ARCaptchaError.self) { try ARCaptchaConfiguration(siteKey: "abc", domain: "https://example.com").validate() }
        #expect(throws: Never.self) { try ARCaptchaConfiguration(siteKey: "abc", domain: "example.com").validate() }
    }

    @Test func tokenExpiry() {
        let token = ARCaptchaToken(value: "t", issuedAt: Date().addingTimeInterval(-121), lifetime: 120)
        #expect(token.isExpired)
        #expect(!ARCaptchaToken(value: "t", lifetime: 120).isExpired)
    }

    @Test func widgetErrorCodesMap() {
        #expect(ARCaptchaError(widgetCode: 203, message: "").code == .answerWrong)
        #expect(ARCaptchaError(widgetCode: 999, message: "").code == .unknown)
    }
}
