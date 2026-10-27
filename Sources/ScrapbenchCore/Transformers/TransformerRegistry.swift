import Foundation

public enum TransformerRegistry {
    /// Every built-in transformer in palette order.
    public static let builtIn: [any Transformer] = [
        UpperCaseTransformer(), LowerCaseTransformer(), TitleCaseTransformer(),
        IdentifierCaseTransformer.camel, IdentifierCaseTransformer.snake,
        IdentifierCaseTransformer.kebab, IdentifierCaseTransformer.constant,

        Base64EncodeTransformer(), Base64DecodeTransformer(),
        URLEncodeTransformer(), URLDecodeTransformer(),
        JSONEscapeTransformer(), JSONUnescapeTransformer(),

        JSONPrettyTransformer(), JSONMinifyTransformer(),
        LineTransformer.sort, LineTransformer.sortUnique, LineTransformer.reverse, LineTransformer.unique,
        LineTransformer.removeBlank, LineTransformer.trimTrailing, LineTransformer.trim,
        LineTransformer.indent, LineTransformer.dedent,
        LineTransformer.joinSpace, LineTransformer.joinComma,
        LineTransformer.splitComma, LineTransformer.splitSpace,

        CLITransformers.split, CLITransformers.join, CLITransformers.comment, CLITransformers.uncomment,

        EpochISOTransformer(), CalculateTransformer(),
    ]

    public static func applicable(to text: String) -> [any Transformer] {
        builtIn.filter { $0.canApply(to: text) }
    }

    public static func transformer(id: String) -> (any Transformer)? {
        builtIn.first { $0.id == id }
    }
}
