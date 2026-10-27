import Foundation

extension CodeGrammar {
    static let javascript = CodeGrammar(aliases: ["js", "javascript", "ts", "typescript", "jsx", "tsx"], rules: [
        .lineCommentSlash,
        .blockComment,
        Rule(#"`(?:[^`\\]|\\.)*`"#, .string),
        .doubleQuoted,
        .singleQuoted,
        .keywords("""
            async await break case catch class const continue debugger default delete do else enum export \
            extends finally for from function if implements import in instanceof interface let new of \
            return static super switch this throw try type typeof var void while with yield \
            public private protected readonly declare namespace abstract as keyof satisfies
            """),
        .keywords("true false null undefined NaN Infinity", kind: .literal),
        .number,
    ])
}
