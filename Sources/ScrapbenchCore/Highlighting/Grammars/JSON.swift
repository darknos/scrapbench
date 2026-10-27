import Foundation

extension CodeGrammar {
    static let json = CodeGrammar(aliases: ["json", "jsonc"], rules: [
        .lineCommentSlash,
        .blockComment,
        Rule(#""(?:[^"\\\n]|\\.)*"(?=\s*:)"#, .key),
        .doubleQuoted,
        .keywords("true false null", kind: .literal),
        .number,
    ])
}
