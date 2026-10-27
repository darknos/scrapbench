import Foundation

public struct JSONPrettyTransformer: Transformer {
    public let id = "json.pretty"
    public let name = "JSON pretty"
    public let group = TransformerGroup.lines
    public init() {}

    public func canApply(to text: String) -> Bool {
        text.utf8.count > transformerParseLimit || JSONFormatter.validate(text)
    }

    public func apply(_ text: String) throws -> String {
        try JSONFormatter.pretty(text) + (Lines(text).trailingNewline ? "\n" : "")
    }
}

public struct JSONMinifyTransformer: Transformer {
    public let id = "json.minify"
    public let name = "JSON minify"
    public let group = TransformerGroup.lines
    public init() {}

    public func canApply(to text: String) -> Bool {
        text.utf8.count > transformerParseLimit || JSONFormatter.validate(text)
    }

    public func apply(_ text: String) throws -> String {
        try JSONFormatter.minify(text) + (Lines(text).trailingNewline ? "\n" : "")
    }
}
