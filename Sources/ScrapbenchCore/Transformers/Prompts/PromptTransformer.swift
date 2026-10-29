import Foundation

/// A `.prompt` file in the transformers folder. The palette lists it like
/// any transformer; the app sends the text to the AI provider instead of `apply`.
public struct PromptTransformer: Transformer, Equatable {
    public static let idPrefix = "prompt."

    public let id: String
    public let name: String
    public let group: TransformerGroup
    public let description: String
    public let url: URL
    public let timeout: Int
    public let systemPrompt: String
    public let model: String?
    public let provider: PromptProvider?
    public let effort: Effort?
    public let service: Bool

    public init(header: ScriptHeader, body: String, url: URL) {
        id = Self.idPrefix + url.deletingPathExtension().lastPathComponent
        name = header.name
        group = header.group
        description = header.description
        self.url = url
        timeout = header.timeout
        systemPrompt = body
        model = header.model
        provider = header.provider
        effort = header.effort
        service = header.service
    }

    public func canApply(to text: String) -> Bool { true }

    public func apply(_ text: String) throws -> String {
        throw TransformError("runs through the app")
    }
}
