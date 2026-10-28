import Foundation

/// A palette section. Built-ins use the constants; scripts name their own.
public struct TransformerGroup: Hashable, Sendable {
    public let name: String
    public init(_ name: String) { self.name = name }

    public static let `case` = TransformerGroup("Case")
    public static let encoding = TransformerGroup("Encoding")
    public static let lines = TransformerGroup("Lines")
    public static let cli = TransformerGroup("CLI")
    public static let time = TransformerGroup("Time")
    public static let math = TransformerGroup("Math")
    public static let scripts = TransformerGroup("Scripts")
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
