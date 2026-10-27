import Foundation

extension CodeGrammar {
    static let shell = CodeGrammar(aliases: ["bash", "sh", "zsh", "shell", "console"], rules: [
        .hashComment,
        .doubleQuoted,
        .singleQuoted,
        .keywords("""
            if then else elif fi for while until do done case esac in function return exit export local \
            readonly source alias unset set shift echo printf cd ls cat grep sed awk xargs curl git make \
            test true false sudo
            """),
        Rule(#"\$(?:\{[^}\n]*\}|\w+|[@*#?$!-])"#, .key),
        .number,
    ])
}
