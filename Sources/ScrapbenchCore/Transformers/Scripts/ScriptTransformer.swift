import Foundation

/// A user script in the transformers folder. The palette lists it like any
/// transformer; the app runs the file (stdin → stdout) instead of `apply`.
public struct ScriptTransformer: Transformer, Equatable {
    public static let idPrefix = "script."

    public let id: String
    public let name: String
    public let group: TransformerGroup
    public let description: String
    public let url: URL
    public let timeout: Int
    public let service: Bool

    public init(id: String, name: String, group: TransformerGroup, description: String, url: URL, timeout: Int, service: Bool = false) {
        self.id = id
        self.name = name
        self.group = group
        self.description = description
        self.url = url
        self.timeout = timeout
        self.service = service
    }

    public init(header: ScriptHeader, url: URL) {
        self.init(id: Self.idPrefix + url.deletingPathExtension().lastPathComponent, name: header.name,
                  group: header.group, description: header.description, url: url, timeout: header.timeout, service: header.service)
    }

    public func canApply(to text: String) -> Bool { true }

    public func apply(_ text: String) throws -> String {
        throw TransformError("runs through the app")
    }
}
