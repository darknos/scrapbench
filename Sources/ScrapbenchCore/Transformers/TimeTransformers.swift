import Foundation

/// Unix epoch (10 digits = seconds, 13 = milliseconds) to ISO 8601 UTC and back.
public struct EpochISOTransformer: Transformer {
    public let id = "time.epochIso"
    public let name = "Epoch ↔ ISO 8601"
    public let group = TransformerGroup.time
    public init() {}

    // ISO8601DateFormatter is not Sendable, so no shared instance under Swift 6.
    private static func formatter(fractional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f
    }

    public func canApply(to text: String) -> Bool { (try? apply(text)) != nil }

    public func apply(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let plain = Self.formatter(fractional: false)
        let fractional = Self.formatter(fractional: true)
        if trimmed.allSatisfy(\.isNumber), let value = Double(trimmed) {
            switch trimmed.count {
            case 10: return plain.string(from: Date(timeIntervalSince1970: value))
            case 13: return fractional.string(from: Date(timeIntervalSince1970: value / 1000))
            default: throw TransformError("not a timestamp")
            }
        }
        if let date = fractional.date(from: trimmed) ?? plain.date(from: trimmed) {
            return String(Int(date.timeIntervalSince1970.rounded(.down)))
        }
        throw TransformError("not a timestamp")
    }
}
