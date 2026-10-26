import Foundation

/// A regex-based grammar for one language. Rules are tried in order and an
/// earlier match claims its characters, so comments and strings go first.
public struct CodeGrammar: Sendable {
    public struct Rule: Sendable {
        let regex: NSRegularExpression
        let kind: TokenKind
        /// Capture group to report; 0 reports the whole match.
        let group: Int

        public init(_ pattern: String, _ kind: TokenKind, options: NSRegularExpression.Options = [], group: Int = 0) {
            regex = try! NSRegularExpression(pattern: pattern, options: options)
            self.kind = kind
            self.group = group
        }
    }

    public let aliases: Set<String>
    public let rules: [Rule]

    public init(aliases: Set<String>, rules: [Rule]) {
        self.aliases = aliases
        self.rules = rules
    }

    public static let all: [CodeGrammar] = [.json, .sql, .shell, .yaml, .go, .javascript, .xml]

    public static func named(_ language: String) -> CodeGrammar? {
        let key = language.lowercased()
        return all.first { $0.aliases.contains(key) }
    }

    public func tokens(in text: NSString, range: NSRange) -> [Token] {
        var claimed: [NSRange] = []
        var tokens: [Token] = []
        for rule in rules {
            rule.regex.enumerateMatches(in: text as String, options: [.withTransparentBounds], range: range) { m, _, _ in
                guard let m else { return }
                let full = m.range
                guard full.length > 0, !claimed.contains(where: { NSIntersectionRange($0, full).length > 0 }) else { return }
                claimed.append(full)
                let r = rule.group == 0 ? full : m.range(at: rule.group)
                guard r.location != NSNotFound, r.length > 0 else { return }
                tokens.append(Token(range: r, kind: rule.kind))
            }
        }
        return tokens
    }
}

extension CodeGrammar.Rule {
    static func keywords(_ words: String, caseInsensitive: Bool = false, kind: TokenKind = .keyword) -> Self {
        let alts = words.split(separator: " ").joined(separator: "|")
        return Self("\\b(?:\(alts))\\b", kind, options: caseInsensitive ? [.caseInsensitive] : [])
    }

    static let number = Self(#"(?<![\w.])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, .number)
    static let doubleQuoted = Self(#""(?:[^"\\\n]|\\.)*""#, .string)
    static let singleQuoted = Self(#"'(?:[^'\\\n]|\\.)*'"#, .string)
    static let lineCommentSlash = Self(#"//[^\n]*"#, .comment)
    static let blockComment = Self(#"/\*[\s\S]*?\*/"#, .comment)
    static let hashComment = Self(#"(?:^|(?<=\s))#[^\n]*"#, .comment)
}
