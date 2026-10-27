import Foundation

extension CodeGrammar {
    static let xml = CodeGrammar(aliases: ["xml", "html", "svg", "xhtml", "plist"], rules: [
        Rule(#"<!--[\s\S]*?-->"#, .comment),
        Rule(#"<!\[CDATA\[[\s\S]*?\]\]>"#, .string),
        Rule(#"<\?[\s\S]*?\?>"#, .comment),
        Rule(#"<!DOCTYPE[^>]*>"#, .comment, options: [.caseInsensitive]),
        .doubleQuoted,
        .singleQuoted,
        Rule(#"</?[A-Za-z][\w:.-]*|/?>"#, .keyword),
        Rule(#"\b[A-Za-z_:][\w:.-]*(?=\s*=)"#, .key),
    ])
}
