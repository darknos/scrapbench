import Foundation

extension CodeGrammar {
    static let go = CodeGrammar(aliases: ["go", "golang"], rules: [
        .lineCommentSlash,
        .blockComment,
        Rule(#"`[^`]*`"#, .string),
        .doubleQuoted,
        Rule(#"'(?:[^'\\\n]|\\.)*'"#, .string),
        .keywords("""
            break case chan const continue default defer else fallthrough for func go goto if import \
            interface map package range return select struct switch type var \
            bool byte rune string error int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 \
            float32 float64 complex64 complex128 uintptr any
            """),
        .keywords("true false nil iota", kind: .literal),
        .number,
    ])
}
