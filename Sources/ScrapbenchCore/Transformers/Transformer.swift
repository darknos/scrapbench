import Foundation

public enum TransformerGroup: String, CaseIterable, Sendable {
    case `case` = "Case"
    case encoding = "Encoding"
    case lines = "Lines"
    case cli = "CLI"
    case time = "Time"
    case math = "Math"
}

/// A pure text → text operation offered in the command palette.
/// `canApply` is a cheap check that never throws; `apply` reports problems
/// as `TransformError`, shown verbatim in the banner after the name.
public protocol Transformer: Sendable {
    var id: String { get }
    var name: String { get }
    var group: TransformerGroup { get }
    func canApply(to text: String) -> Bool
    func apply(_ text: String) throws -> String
}

public struct TransformError: Error, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

/// Above this many bytes, `canApply` checks that would parse the whole
/// text return true instead and leave the verdict to `apply`.
public let transformerParseLimit = 1_048_576
