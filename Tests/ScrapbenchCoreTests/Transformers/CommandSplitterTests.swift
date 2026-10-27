import Testing
@testable import ScrapbenchCore

@Suite struct CommandSplitterTests {
    let docker = #"docker run --rm -it -v "$PWD:/src" -w /src node:20 npm test"#

    @Test func tokensKeepQuotes() {
        #expect(CommandSplitter.tokens(#"a "b c" 'd e' f"#) == ["a", "\"b c\"", "'d e'", "f"])
    }

    @Test func splitMatchesSpec() {
        #expect(CommandSplitter.split(docker) ==
            "docker run \\\n  --rm \\\n  -it \\\n  -v \"$PWD:/src\" \\\n  -w /src node:20 npm test")
    }

    @Test func splitPipesAndFlagValues() {
        #expect(CommandSplitter.split("cat f.txt | grep -i err --count && echo done") ==
            "cat f.txt \\\n  | grep \\\n  -i err \\\n  --count \\\n  && echo done")
    }

    @Test func roundTrip() throws {
        #expect(CommandSplitter.join(CommandSplitter.split(docker)) == docker)
        #expect(try CLITransformers.join.apply("a \\\n  -b \\\n  c\n") == "a -b c\n")
    }

    @Test func splitTransformerApplicability() {
        #expect(CLITransformers.split.canApply(to: docker))
        #expect(!CLITransformers.split.canApply(to: "single"))
        #expect(!CLITransformers.split.canApply(to: "a b\nc d"))
        #expect(CLITransformers.join.canApply(to: "a\nb"))
    }

    @Test func commentUncomment() throws {
        #expect(try CLITransformers.comment.apply("a\n\nb") == "# a\n\n# b")
        #expect(try CLITransformers.uncomment.apply("# a\n#b\n") == "a\nb\n")
        #expect(!CLITransformers.comment.canApply(to: "# a\n# b"))
        #expect(!CLITransformers.uncomment.canApply(to: "# a\nb"))
    }
}
