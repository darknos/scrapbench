import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct PromptRequestTests {
    func endpoint(provider: PromptProvider = .anthropic, base: String = "https://api.anthropic.com",
                  key: String? = "sk-a", model: String = "claude-opus-5-5", effort: Effort = .low) -> PromptEndpoint {
        PromptEndpoint(provider: provider, baseURL: URL(string: base)!, apiKey: key, model: model, effort: effort)
    }
    func body(_ r: URLRequest) throws -> [String: Any] {
        let data = try #require(r.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    func header(_ r: URLRequest, _ name: String) -> String? {
        r.allHTTPHeaderFields?.first { $0.key.lowercased() == name }?.value
    }

    @Test func anthropicRequest() throws {
        let r = PromptRequest.build(endpoint: endpoint(), systemPrompt: "Fix.", input: "hi")
        #expect(r.httpMethod == "POST")
        #expect(r.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(header(r, "x-api-key") == "sk-a")
        #expect(header(r, "anthropic-version") == "2026-10-21")
        #expect(header(r, "anthropic-beta") == "server-side-fallback-2026-07-01")
        #expect(header(r, "content-type") == "application/json")
        #expect(header(r, "authorization") == nil)
        let b = try body(r)
        #expect(b["model"] as? String == "claude-opus-5-5")
        #expect(b["max_tokens"] as? Int == 16000)
        #expect(b["system"] as? String == "Fix.")
        #expect(b["messages"] as? [[String: String]] == [["role": "user", "content": "hi"]])
        #expect((b["output_config"] as? [String: String]) == ["effort": "low"])
        #expect(b["fallbacks"] as? String == "default")
        #expect(b["thinking"] == nil && b["temperature"] == nil)
    }

    @Test func haikuHasNoFallbacks() throws {
        let r = PromptRequest.build(endpoint: endpoint(model: "claude-haiku-5-5"), systemPrompt: "s", input: "i")
        #expect(header(r, "anthropic-beta") == nil)
        #expect(try body(r)["fallbacks"] == nil)
    }

    @Test func otherRequest() throws {
        let r = PromptRequest.build(endpoint: endpoint(provider: .other, base: "http://localhost:11434/v1/", key: nil, model: "llama3"),
                                    systemPrompt: "Fix.", input: "hi")
        #expect(r.url?.absoluteString == "http://localhost:11434/v1/chat/completions")
        #expect(header(r, "authorization") == nil)
        #expect(header(r, "x-api-key") == nil)
        #expect(header(r, "content-type") == "application/json")
        let b = try body(r)
        #expect(b["model"] as? String == "llama3")
        #expect(b["max_tokens"] == nil && b["max_completion_tokens"] == nil)
        #expect(b["messages"] as? [[String: String]] == [["role": "system", "content": "Fix."], ["role": "user", "content": "hi"]])
        #expect(b["output_config"] == nil && b["fallbacks"] == nil)
    }

    @Test func otherRequestWithKeyAndExplicitPath() throws {
        let r = PromptRequest.build(endpoint: endpoint(provider: .other, base: "https://x/v1/chat/completions", key: "k", model: "m"),
                                    systemPrompt: "s", input: "i")
        #expect(r.url?.absoluteString == "https://x/v1/chat/completions")
        #expect(header(r, "authorization") == "Bearer k")
    }

    @Test func anthropicBaseWithSlashAndCustomMaxTokens() throws {
        let r = PromptRequest.build(endpoint: endpoint(base: "http://localhost:8089/"), systemPrompt: "s", input: "i", maxTokens: 16)
        #expect(r.url?.absoluteString == "http://localhost:8089/v1/messages")
        #expect(try body(r)["max_tokens"] as? Int == 16)
    }

    @Test func inputIsSentVerbatim() throws {
        let input = "a\r\nb 🙂\n"
        let r = PromptRequest.build(endpoint: endpoint(), systemPrompt: "s", input: input)
        let b = try body(r)
        let messages = try #require(b["messages"] as? [[String: String]])
        #expect(messages[0]["content"] == input)
    }
}
