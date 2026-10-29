import Foundation

/// Builds the one request a prompt run makes: a system prompt and one user
/// message, no streaming, no tools, no history.
public enum PromptRequest {
    public static let maxTokens = 16000
    public static let anthropicVersion = "2026-10-21"
    /// Lets a request the safety classifier declines run on a substitute
    /// model inside the same call. Haiku has no fallback, so it is left out there.
    public static let fallbackBeta = "server-side-fallback-2026-07-01"
    static let noFallbackPrefix = "claude-haiku"

    public static func url(for endpoint: PromptEndpoint) -> URL {
        var base = endpoint.baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        switch endpoint.provider {
        case .anthropic:
            return URL(string: base + "/v1/messages")!
        case .other:
            let path = "/chat/completions"
            return URL(string: base.hasSuffix(path) ? base : base + path)!
        }
    }

    public static func build(endpoint: PromptEndpoint, systemPrompt: String, input: String,
                             maxTokens: Int = maxTokens) -> URLRequest {
        var request = URLRequest(url: url(for: endpoint))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = ["model": endpoint.model]
        switch endpoint.provider {
        case .anthropic:
            body["max_tokens"] = maxTokens
            request.setValue(endpoint.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
            body["system"] = systemPrompt
            body["messages"] = [["role": "user", "content": input]]
            body["output_config"] = ["effort": endpoint.effort.rawValue]
            if !endpoint.model.hasPrefix(noFallbackPrefix) {
                request.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta")
                body["fallbacks"] = "default"
            }
        case .other:
            // No output cap: OpenAI's reasoning models reject `max_tokens`
            // and every listed server has a default of its own.
            if let key = endpoint.apiKey {
                request.setValue("Bearer " + key, forHTTPHeaderField: "authorization")
            }
            body["messages"] = [["role": "system", "content": systemPrompt], ["role": "user", "content": input]]
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return request
    }
}
