import Foundation

/// Token-level JSON reformatter: validates syntax and re-emits the tokens
/// with new whitespace. Strings and numbers are copied verbatim, so key
/// order and number spelling survive, unlike with `JSONSerialization`.
public enum JSONFormatter {
    public static func pretty(_ text: String) throws -> String {
        var formatter = Formatter(text, pretty: true)
        return try formatter.run()
    }

    public static func minify(_ text: String) throws -> String {
        var formatter = Formatter(text, pretty: false)
        return try formatter.run()
    }

    public static func validate(_ text: String) -> Bool { (try? minify(text)) != nil }
}

/// Iterative, with an explicit container stack: `canApply` runs this on the
/// main thread for whatever is selected, and recursion overflowed the stack
/// on a few thousand nested brackets.
private struct Formatter {
    private enum State { case value, element, afterValue }
    private struct Container { let close: Unicode.Scalar; let isObject: Bool }

    private let scalars: [Unicode.Scalar]
    private let pretty: Bool
    private var index = 0
    private var line = 1
    private var column = 1
    private var stack: [Container] = []
    private var out = ""

    init(_ text: String, pretty: Bool) {
        scalars = Array(text.unicodeScalars)
        self.pretty = pretty
    }

    mutating func run() throws -> String {
        skipWhitespace()
        var state = State.value
        while true {
            switch state {
            case .value:
                state = try beginValue()
            case .element:
                try elementPrefix()
                state = .value
            case .afterValue:
                if stack.isEmpty {
                    skipWhitespace()
                    if index < scalars.count { throw unexpected() }
                    return out
                }
                state = try afterValue()
            }
        }
    }

    private var peek: Unicode.Scalar? { index < scalars.count ? scalars[index] : nil }

    private func unexpected() -> TransformError {
        index < scalars.count ? TransformError("unexpected token at \(line):\(column)") : TransformError("unexpected end of input")
    }

    private mutating func advance() {
        if scalars[index] == "\n" { line += 1; column = 1 } else { column += 1 }
        index += 1
    }

    private mutating func emit(_ scalar: Unicode.Scalar) {
        out.unicodeScalars.append(scalar)
        advance()
    }

    private mutating func skipWhitespace() {
        while let s = peek, s == " " || s == "\n" || s == "\t" || s == "\r" { advance() }
    }

    private mutating func newline() {
        if pretty { out += "\n" + String(repeating: "  ", count: stack.count) }
    }

    /// Emits a scalar value, or opens a container and leaves its first element pending.
    private mutating func beginValue() throws -> State {
        guard let s = peek else { throw unexpected() }
        switch s {
        case "{", "[":
            let close: Unicode.Scalar = s == "{" ? "}" : "]"
            emit(s)
            skipWhitespace()
            if peek == close {
                emit(close)
                return .afterValue
            }
            stack.append(Container(close: close, isObject: s == "{"))
            return .element
        case "\"": try string()
        case "t": try literal("true")
        case "f": try literal("false")
        case "n": try literal("null")
        case "-", "0"..."9": try number()
        default: throw unexpected()
        }
        return .afterValue
    }

    /// Indentation and, in objects, the `"key":` before the element's value.
    private mutating func elementPrefix() throws {
        newline()
        skipWhitespace()
        if stack.last?.isObject == true {
            guard peek == "\"" else { throw unexpected() }
            try string()
            skipWhitespace()
            guard peek == ":" else { throw unexpected() }
            emit(":")
            if pretty { out += " " }
            skipWhitespace()
        }
    }

    private mutating func afterValue() throws -> State {
        skipWhitespace()
        if peek == "," {
            emit(",")
            return .element
        }
        if let container = stack.last, peek == container.close {
            stack.removeLast()
            newline()
            emit(container.close)
            return .afterValue
        }
        throw unexpected()
    }

    private mutating func string() throws {
        emit("\"")
        while let s = peek {
            if s == "\"" { emit(s); return }
            if s == "\\" {
                emit(s)
                guard peek != nil else { break }
            }
            emit(scalars[index])
        }
        throw unexpected()
    }

    private mutating func number() throws {
        if peek == "-" { emit("-") }
        guard let first = peek, ("0"..."9").contains(first) else { throw unexpected() }
        while let s = peek, ("0"..."9").contains(s) { emit(s) }
        if peek == "." {
            emit(".")
            guard let s = peek, ("0"..."9").contains(s) else { throw unexpected() }
            while let s = peek, ("0"..."9").contains(s) { emit(s) }
        }
        if peek == "e" || peek == "E" {
            emit(scalars[index])
            if peek == "+" || peek == "-" { emit(scalars[index]) }
            guard let s = peek, ("0"..."9").contains(s) else { throw unexpected() }
            while let s = peek, ("0"..."9").contains(s) { emit(s) }
        }
    }

    private mutating func literal(_ word: String) throws {
        for expected in word.unicodeScalars {
            guard peek == expected else { throw unexpected() }
            emit(expected)
        }
    }
}
