import Foundation

/// Lines of a text plus whether it ended with a newline, so line-based
/// transformers rebuild the text with the same ending and `\n` only.
public struct Lines: Sendable {
    public let lines: [String]
    public let trailingNewline: Bool

    public init(_ text: String) {
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n")
        trailingNewline = normalised.hasSuffix("\n")
        let body = trailingNewline ? String(normalised.dropLast()) : normalised
        lines = body.components(separatedBy: "\n")
    }

    public func joined(_ lines: [String]) -> String {
        lines.joined(separator: "\n") + (trailingNewline ? "\n" : "")
    }

    public func joined() -> String { joined(lines) }
}
