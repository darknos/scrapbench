import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct PromptResponseTests {
    func parse(_ provider: PromptProvider, _ status: Int, _ body: String) -> Result<String, TransformError> {
        PromptResponse.parse(provider: provider, status: status, data: Data(body.utf8))
    }
    func error(_ message: String) -> Result<String, TransformError> { .failure(TransformError(message)) }

    @Test func anthropicTextBlocksAreJoinedAndTrimmed() {
        let body = #"{"stop_reason":"end_turn","content":[{"type":"text","text":"Hi"},{"type":"text","text":" there\n"}]}"#
        #expect(parse(.anthropic, 200, body) == .success("Hi there"))
    }

    @Test func thinkingAndFallbackBlocksAreSkipped() {
        let body = #"{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":""},{"type":"fallback","from":{"model":"a"},"to":{"model":"b"}},{"type":"text","text":"Hi"},{"type":"text","text":" there\n"}]}"#
        #expect(parse(.anthropic, 200, body) == .success("Hi there"))
    }

    @Test func anthropicStopReasons() {
        #expect(parse(.anthropic, 200, #"{"stop_reason":"refusal","content":[]}"#) == error("refused"))
        #expect(parse(.anthropic, 200, #"{"stop_reason":"refusal"}"#) == error("refused"))
        #expect(parse(.anthropic, 200, #"{"stop_reason":"max_tokens","content":[{"type":"text","text":"x"}]}"#) == error("output too long"))
    }

    @Test func otherContentAndFinishReasons() {
        #expect(parse(.other, 200, #"{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"Hi\n"}}]}"#) == .success("Hi"))
        #expect(parse(.other, 200, #"{"choices":[{"finish_reason":"length","message":{"content":"x"}}]}"#) == error("output too long"))
        #expect(parse(.other, 200, #"{"choices":[{"finish_reason":"content_filter","message":{"content":""}}]}"#) == error("refused"))
    }

    @Test func otherRefusalFieldWithNullContent() {
        #expect(parse(.other, 200, #"{"choices":[{"finish_reason":"stop","message":{"content":null,"refusal":"no"}}]}"#) == error("refused"))
    }

    @Test func otherContentAsParts() {
        let body = #"{"choices":[{"message":{"content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}}]}"#
        #expect(parse(.other, 200, body) == .success("ab"))
    }

    @Test func emptyAnswerIsAnError() {
        #expect(parse(.anthropic, 200, #"{"stop_reason":"end_turn","content":[{"type":"text","text":"\n\n"}]}"#) == error("empty output"))
        #expect(parse(.other, 200, #"{"choices":[{"message":{"content":""}}]}"#) == error("empty output"))
    }

    @Test func badResponses() {
        #expect(parse(.other, 200, "<html>portal</html>") == error("bad response"))
        #expect(parse(.other, 200, "{}") == error("bad response"))
        #expect(parse(.anthropic, 200, #"{"content":"nope"}"#) == error("bad response"))
        #expect(parse(.anthropic, 204, "") == error("bad response"))
    }

    @Test func statusErrors() {
        let anthropicError = #"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#
        #expect(parse(.anthropic, 401, anthropicError) == error("401 invalid api key"))
        #expect(parse(.other, 401, "") == error("401 invalid api key"))
        #expect(parse(.anthropic, 403, "") == error("403 not allowed"))
        #expect(parse(.anthropic, 404, "") == error("404 unknown model or URL"))
        #expect(parse(.anthropic, 429, anthropicError) == error("rate limited"))
        #expect(parse(.anthropic, 529, "") == error("overloaded"))
        #expect(parse(.other, 503, "") == error("overloaded"))
    }

    @Test func otherStatusUsesTheMessage() {
        #expect(parse(.anthropic, 400, #"{"error":{"type":"invalid_request_error","message":"max_tokens: too large"}}"#) == error("400 max_tokens: too large"))
        #expect(parse(.anthropic, 400, #"{"error":{"type":"invalid_request_error"}}"#) == error("400 invalid_request_error"))
        #expect(parse(.other, 500, "oops") == error("500 error"))
        #expect(parse(.other, 400, #"{"error":{"message":"Unsupported parameter: max_tokens"}}"#) == error("400 unsupported parameter: max_tokens"))
        #expect(parse(.other, 500, #"{"error":"model 'x' not found"}"#) == error("500 model 'x' not found"))
        let long = String(repeating: "x", count: 100)
        #expect(parse(.other, 400, #"{"error":{"message":"\#(long)"}}"#) == error("400 " + String(repeating: "x", count: 80)))
    }

    @Test func onlyTrailingNewlinesAreTrimmed() {
        #expect(PromptResponse.trimmed("  a\n\nb\r\n\n") == "  a\n\nb")
        #expect(PromptResponse.trimmed("a  ") == "a  ")
    }

    @Test func transportMessages() {
        #expect(PromptResponse.message(forURLError: .timedOut, timeout: 60) == "timed out after 60 s")
        #expect(PromptResponse.message(forURLError: .notConnectedToInternet, timeout: 1) == "offline")
        #expect(PromptResponse.message(forURLError: .cannotConnectToHost, timeout: 1) == "offline")
        #expect(PromptResponse.message(forURLError: .dnsLookupFailed, timeout: 1) == "offline")
        #expect(PromptResponse.message(forURLError: .cannotFindHost, timeout: 1) == "offline")
        #expect(PromptResponse.message(forURLError: .networkConnectionLost, timeout: 1) == "offline")
        #expect(PromptResponse.message(forURLError: .cancelled, timeout: 1) == "cancelled")
        #expect(PromptResponse.message(forURLError: .appTransportSecurityRequiresSecureConnection, timeout: 1) == "http needs https, see Settings → AI")
    }
}
