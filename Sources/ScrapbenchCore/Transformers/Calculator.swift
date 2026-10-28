import Expression
import Foundation

/// Arithmetic over the `Expression` package, with Scrapbench's error
/// messages and number formatting.
public enum Calculator {
    public static func evaluate(_ expression: String) throws -> Double {
        let value: Double
        do {
            value = try Expression(expression).evaluate()
        } catch {
            let message = "\(error)"
            throw TransformError(message.lowercased().contains("division by zero") ? "division by zero" : message)
        }
        if value.isInfinite { throw TransformError("division by zero") }
        if value.isNaN { throw TransformError("not a number") }
        return value
    }

    /// Integers without a fraction, everything else with up to 10
    /// significant digits and no trailing zeros.
    public static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        return String(format: "%.10g", value)
    }
}

public struct CalculateTransformer: Transformer, LineAware {
    public let id = "calc.evaluate"
    public let name = "Calculate"
    public let description = "3+4 = 7, one line each"
    public let group = TransformerGroup.math
    private static let operators = CharacterSet(charactersIn: "+-*/%(")
    public init() {}

    public func canApply(to text: String) -> Bool { canApply(lines: Lines(text)) }

    func canApply(lines: Lines) -> Bool {
        guard lines.lines.contains(where: { Self.expression($0).rangeOfCharacter(from: Self.operators) != nil }) else {
            return false
        }
        if lines.byteCount > transformerParseLimit { return true }
        return lines.lines.allSatisfy { line in
            line.allSatisfy(\.isWhitespace) || (try? Calculator.evaluate(Self.expression(line))) != nil
        }
    }

    public func apply(_ text: String) throws -> String {
        let lines = Lines(text)
        return lines.joined(try lines.lines.map { line in
            if line.allSatisfy(\.isWhitespace) { return line }
            let expression = Self.expression(line)
            let value = try Calculator.evaluate(expression)
            return "\(expression) = \(Calculator.format(value))"
        })
    }

    /// The line without a previous ` = result`, trimmed on the right.
    private static func expression(_ line: String) -> String {
        let stripped = line.lastIndex(of: "=").map { line[..<$0] } ?? Substring(line)
        return String(stripped.reversed().drop(while: \.isWhitespace).reversed())
    }
}
