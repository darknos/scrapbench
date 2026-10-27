import Foundation

/// Markdown-lite highlighting for scraps, with fenced code blocks delegated to `CodeGrammar`.
public struct MarkdownHighlighter: SyntaxHighlighter {
    private typealias Rule = CodeGrammar.Rule

    private static let lineRules: [Rule] = [
        Rule(#"^#{1,6} [^\n]*$"#, .heading, options: [.anchorsMatchLines]),
        Rule(#"^> ?[^\n]*$"#, .quote, options: [.anchorsMatchLines]),
        Rule(#"^\s*[-*] \[[xX]\] [^\n]*$"#, .checkboxDone, options: [.anchorsMatchLines]),
        Rule(#"^\s*([-*+]|\d+\.)(?= )"#, .listMarker, options: [.anchorsMatchLines], group: 1),
    ]

    private static let inlineRules: [Rule] = [
        Rule(#"`[^`\n]+`"#, .inlineCode),
        Rule(#"\[[^\]\n]+\]\([^)\s]+\)"#, .link),
        Rule(#"\bhttps?://[^\s<>()\[\]]+[^\s<>()\[\].,;:!?'"]"#, .link),
        Rule(#"\*\*[^*\n]+\*\*"#, .bold),
        Rule(#"(?<![*\w])\*[^*\n]+\*(?![*\w])"#, .italic),
    ]

    public init() {}

    public func tokens(in text: NSString, range: NSRange, codeBlocks map: CodeBlockMap) -> [Token] {
        var tokens: [Token] = []

        // Markdown rules run on the gaps between code blocks that touch the requested range.
        var cursor = range.location
        let end = range.upperBound
        for block in map.blocks(intersecting: range) {
            if block.whole.location > cursor {
                tokens += markdownTokens(in: text, range: NSRange(location: cursor, length: block.whole.location - cursor))
            }
            tokens += codeTokens(for: block, in: text)
            cursor = max(cursor, block.whole.upperBound)
        }
        if cursor < end {
            tokens += markdownTokens(in: text, range: NSRange(location: cursor, length: end - cursor))
        }
        return tokens
    }

    private func markdownTokens(in text: NSString, range: NSRange) -> [Token] {
        // Widen to whole lines so anchored rules see their line starts.
        let lines = text.lineRange(for: range)
        var tokens: [Token] = []
        for (left, date, right) in Separator.matches(in: text, range: lines) {
            tokens.append(Token(range: left, kind: .separatorDashes))
            tokens.append(Token(range: date, kind: .separatorDate))
            tokens.append(Token(range: right, kind: .separatorDashes))
        }
        let lineGrammar = CodeGrammar(aliases: [], rules: Self.lineRules)
        tokens += lineGrammar.tokens(in: text, range: lines)
        let inlineGrammar = CodeGrammar(aliases: [], rules: Self.inlineRules)
        tokens += inlineGrammar.tokens(in: text, range: lines)
        return tokens
    }

    private func codeTokens(for block: CodeBlock, in text: NSString) -> [Token] {
        var tokens = [
            Token(range: block.whole, kind: .codeBlockBackground),
            Token(range: block.fenceOpen, kind: .codeFence),
        ]
        if let close = block.fenceClose { tokens.append(Token(range: close, kind: .codeFence)) }
        if let lang = block.language, let grammar = CodeGrammar.named(lang) {
            tokens += grammar.tokens(in: text, range: block.body)
        }
        return tokens
    }
}
