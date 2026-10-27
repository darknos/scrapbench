import Foundation

public struct Base64EncodeTransformer: Transformer {
    public let id = "base64.encode"
    public let name = "Base64 encode"
    public let group = TransformerGroup.encoding
    public init() {}
    public func canApply(to text: String) -> Bool { true }
    public func apply(_ text: String) throws -> String { Data(text.utf8).base64EncodedString() }
}

public struct Base64DecodeTransformer: Transformer {
    public let id = "base64.decode"
    public let name = "Base64 decode"
    public let group = TransformerGroup.encoding
    public init() {}

    /// Short words such as "OK" or "The" are valid Base64 of a byte or two,
    /// so the check also wants some length and no control characters in the result.
    public func canApply(to text: String) -> Bool {
        if text.utf8.count > transformerParseLimit { return true }
        let compact = text.filter { !$0.isWhitespace }
        guard compact.count >= 8, let decoded = try? Self.decode(compact) else { return false }
        return !decoded.unicodeScalars.contains { $0.value < 0x20 && $0 != "\t" && $0 != "\n" && $0 != "\r" }
    }

    public func apply(_ text: String) throws -> String {
        try Self.decode(text.filter { !$0.isWhitespace })
    }

    private static func decode(_ compact: String) throws -> String {
        var padded = compact
        let remainder = padded.count % 4
        if remainder != 0 { padded += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: padded) else { throw TransformError("not valid Base64") }
        guard let string = String(data: data, encoding: .utf8) else {
            throw TransformError("decoded bytes are not UTF-8 text")
        }
        return string
    }
}

public struct URLEncodeTransformer: Transformer {
    public let id = "url.encode"
    public let name = "URL encode"
    public let group = TransformerGroup.encoding
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    public init() {}
    public func canApply(to text: String) -> Bool { true }
    public func apply(_ text: String) throws -> String {
        text.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? text
    }
}

public struct URLDecodeTransformer: Transformer {
    public let id = "url.decode"
    public let name = "URL decode"
    public let group = TransformerGroup.encoding
    private static let escape = try! NSRegularExpression(pattern: "%[0-9A-Fa-f]{2}")
    public init() {}

    public func canApply(to text: String) -> Bool {
        Self.escape.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    public func apply(_ text: String) throws -> String {
        guard let decoded = text.removingPercentEncoding else { throw TransformError("invalid percent escape") }
        return decoded
    }
}

public struct JSONEscapeTransformer: Transformer {
    public let id = "json.escape"
    public let name = "JSON string escape"
    public let group = TransformerGroup.encoding
    public init() {}
    public func canApply(to text: String) -> Bool { true }

    public func apply(_ text: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return String(decoding: try encoder.encode(text), as: UTF8.self)
    }
}

public struct JSONUnescapeTransformer: Transformer {
    public let id = "json.unescape"
    public let name = "JSON string unescape"
    public let group = TransformerGroup.encoding
    public init() {}

    public func canApply(to text: String) -> Bool {
        text.utf8.count > transformerParseLimit || (try? apply(text)) != nil
    }

    public func apply(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\""),
              let string = try? JSONDecoder().decode(String.self, from: Data(trimmed.utf8)) else {
            throw TransformError("not a JSON string literal")
        }
        return string
    }
}
