import Foundation

extension CodeGrammar {
    static let yaml = CodeGrammar(aliases: ["yaml", "yml"], rules: [
        .hashComment,
        .doubleQuoted,
        .singleQuoted,
        Rule(#"^\s*-?\s*[\w.\-/]+:(?=\s|$)"#, .key, options: [.anchorsMatchLines]),
        .keywords("true false null yes no on off ~", kind: .literal),
        .number,
    ])
}
