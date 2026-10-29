import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct PromptEndpointTests {
    func settings(provider: PromptProvider = .anthropic, anthropicKey: String? = "sk-a", otherKey: String? = nil,
                  otherModel: String = "llama3", otherBaseURL: String = AISettings.defaultOtherBaseURL,
                  anthropicBaseURL: String = AISettings.defaultAnthropicBaseURL) -> AISettings {
        AISettings(provider: provider, anthropicModel: AISettings.defaultAnthropicModel, anthropicBaseURL: anthropicBaseURL,
                   anthropicKey: anthropicKey, otherModel: otherModel, otherBaseURL: otherBaseURL, otherKey: otherKey)
    }
    func prompt(model: String? = nil, provider: PromptProvider? = nil, effort: Effort? = nil) -> PromptTransformer {
        PromptTransformer(header: ScriptHeader(name: "P", model: model, provider: provider, effort: effort), body: "x",
                          url: URL(fileURLWithPath: "/t/p.prompt"))
    }

    @Test func anthropicDefaults() throws {
        let e = try PromptEndpoint.resolve(for: prompt(), settings: settings()).get()
        #expect(e == PromptEndpoint(provider: .anthropic, baseURL: URL(string: "https://api.anthropic.com")!,
                                    apiKey: "sk-a", model: "claude-opus-5-5", effort: .low))
    }

    @Test func anthropicNeedsAKey() {
        #expect(PromptEndpoint.resolve(for: prompt(), settings: settings(anthropicKey: nil))
                == .failure(TransformError("no API key, see Settings → AI")))
        #expect(PromptEndpoint.resolve(for: prompt(), settings: settings(anthropicKey: ""))
                == .failure(TransformError("no API key, see Settings → AI")))
    }

    @Test func headerOverridesWin() throws {
        let e = try PromptEndpoint.resolve(for: prompt(model: "m", provider: .other, effort: .high),
                                           settings: settings(provider: .anthropic, otherKey: "k")).get()
        #expect(e.provider == .other)
        #expect(e.model == "m")
        #expect(e.apiKey == "k")
        #expect(e.baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(e.effort == .high)
    }

    @Test func otherKeyIsOptionalAndEmptyMeansNone() throws {
        let e = try PromptEndpoint.resolve(for: prompt(), settings: settings(provider: .other, otherKey: "")).get()
        #expect(e.apiKey == nil)
    }

    @Test func otherNeedsAModel() {
        #expect(PromptEndpoint.resolve(for: prompt(), settings: settings(provider: .other, otherModel: " "))
                == .failure(TransformError("no model, see Settings → AI")))
    }

    @Test func badBaseURLIsReported() {
        #expect(PromptEndpoint.resolve(for: prompt(), settings: settings(provider: .other, otherBaseURL: "localhost:11434"))
                == .failure(TransformError("bad base URL, see Settings → AI")))
        #expect(PromptEndpoint.resolve(for: prompt(), settings: settings(anthropicBaseURL: ""))
                == .failure(TransformError("bad base URL, see Settings → AI")))
    }

    @Test func constants() {
        #expect(AISettings.anthropicModels == ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"])
        #expect(AISettings.defaultAnthropicModel == "claude-opus-5-5")
    }
}
