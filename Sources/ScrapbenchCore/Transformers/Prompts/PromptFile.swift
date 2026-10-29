import Foundation

/// A `.prompt` file: the same `# @key value` header as a script, then the
/// system prompt. Only lines that parse as header keys are removed; a
/// Markdown heading or prose inside the first lines stays in the prompt.
public enum PromptFile {
    public static let fileExtension = "prompt"
    public static let defaultTimeout = 60

    public struct Parsed: Equatable {
        public let header: ScriptHeader
        public let body: String
    }

    public static func parse(_ text: String, file: String) -> Result<Parsed, ScriptProblem> {
        let text = ScriptHeader.normalized(text)
        let header: ScriptHeader
        switch ScriptHeader.parse(text, file: file, defaultTimeout: defaultTimeout, defaultGroup: .ai) {
        case .failure(let problem): return .failure(problem)
        case .success(let parsed): header = parsed
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let kept = lines.enumerated().filter { index, line in
            index >= ScriptHeader.maxLines || ScriptHeader.headerLine(line) == nil
        }.map { $0.element }
        let body = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return .failure(ScriptProblem(file: file, reason: "empty prompt")) }
        return .success(Parsed(header: header, body: body))
    }
}
