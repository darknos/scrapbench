import Foundation

/// The AI preferences as the app stores them: a provider, and per provider
/// a model, a base URL and a key. Keys come from the Keychain, the rest
/// from the defaults; Core only reads the values.
public struct AISettings: Equatable, Sendable {
    public static let defaultAnthropicModel = "claude-opus-5-5"
    public static let anthropicModels = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
    public static let defaultAnthropicBaseURL = "https://api.anthropic.com"
    public static let defaultOtherBaseURL = "https://api.openai.com/v1"

    public var provider: PromptProvider
    public var anthropicModel: String
    public var anthropicBaseURL: String
    public var anthropicKey: String?
    public var otherModel: String
    public var otherBaseURL: String
    public var otherKey: String?

    public init(provider: PromptProvider, anthropicModel: String, anthropicBaseURL: String, anthropicKey: String?,
                otherModel: String, otherBaseURL: String, otherKey: String?) {
        self.provider = provider
        self.anthropicModel = anthropicModel
        self.anthropicBaseURL = anthropicBaseURL
        self.anthropicKey = anthropicKey
        self.otherModel = otherModel
        self.otherBaseURL = otherBaseURL
        self.otherKey = otherKey
    }
}

/// Where one prompt run goes: the settings with the prompt's header
/// overrides applied and the missing pieces reported.
public struct PromptEndpoint: Equatable, Sendable {
    public static let defaultEffort = Effort.low
    static let settingsHint = ", see Settings → AI"

    public let provider: PromptProvider
    public let baseURL: URL
    public let apiKey: String?
    public let model: String
    public let effort: Effort

    public init(provider: PromptProvider, baseURL: URL, apiKey: String?, model: String, effort: Effort) {
        self.provider = provider
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.effort = effort
    }

    public static func resolve(for prompt: PromptTransformer, settings: AISettings) -> Result<PromptEndpoint, TransformError> {
        resolve(provider: prompt.provider, model: prompt.model, effort: prompt.effort, settings: settings)
    }

    public static func resolve(provider: PromptProvider?, model: String?, effort: Effort?,
                               settings: AISettings) -> Result<PromptEndpoint, TransformError> {
        let provider = provider ?? settings.provider
        let key = (provider == .anthropic ? settings.anthropicKey : settings.otherKey)
            .flatMap { $0.isEmpty ? nil : $0 }
        if provider == .anthropic, key == nil {
            return .failure(TransformError("no API key" + settingsHint))
        }
        let model = (model ?? (provider == .anthropic ? settings.anthropicModel : settings.otherModel))
            .trimmingCharacters(in: .whitespaces)
        guard !model.isEmpty else { return .failure(TransformError("no model" + settingsHint)) }
        let raw = provider == .anthropic ? settings.anthropicBaseURL : settings.otherBaseURL
        guard let url = URL(string: raw.trimmingCharacters(in: .whitespaces)), url.scheme != nil, url.host != nil else {
            return .failure(TransformError("bad base URL" + settingsHint))
        }
        return .success(PromptEndpoint(provider: provider, baseURL: url, apiKey: key, model: model,
                                       effort: effort ?? defaultEffort))
    }
}
