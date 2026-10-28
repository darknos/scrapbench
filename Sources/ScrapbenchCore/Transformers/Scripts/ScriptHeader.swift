import Foundation

/// Why a file in the transformers folder is not offered in the palette.
public struct ScriptProblem: Error, Equatable, Sendable {
    public let file: String
    public let reason: String
    public init(file: String, reason: String) {
        self.file = file
        self.reason = reason
    }
}

/// The `@key value` comment lines at the top of a script transformer.
public struct ScriptHeader: Equatable, Sendable {
    public let name: String
    public let group: TransformerGroup
    public let description: String
    public let timeout: Int
    public let service: Bool

    public static let maxLines = 20
    public static let defaultTimeout = 30

    public init(name: String, group: TransformerGroup = .scripts, description: String = "", timeout: Int = defaultTimeout, service: Bool = false) {
        self.name = name
        self.group = group
        self.description = description
        self.timeout = timeout
        self.service = service
    }

    /// Reads the first `maxLines` lines; the first occurrence of a key wins.
    /// `file` names the script in the problem.
    public static func parse(_ text: String, file: String) -> Result<ScriptHeader, ScriptProblem> {
        var values: [String: String] = [:]
        for line in text.split(separator: "\n", maxSplits: maxLines, omittingEmptySubsequences: false).prefix(maxLines) {
            guard let (key, value) = headerLine(line), values[key] == nil else { continue }
            values[key] = value
        }
        guard let name = values["name"], !name.isEmpty else {
            return .failure(ScriptProblem(file: file, reason: "no @name"))
        }
        var timeout = defaultTimeout
        if let raw = values["timeout"] {
            guard let seconds = Int(raw), seconds > 0 else {
                return .failure(ScriptProblem(file: file, reason: "bad @timeout"))
            }
            timeout = seconds
        }
        return .success(ScriptHeader(
            name: name,
            group: values["group"].map { TransformerGroup($0) } ?? .scripts,
            description: values["description"] ?? "",
            timeout: timeout,
            service: values["service"] != nil))
    }

    private static func headerLine(_ line: Substring) -> (String, String)? {
        var rest = line.drop(while: { $0 == " " || $0 == "\t" })
        if rest.hasPrefix("#") { rest = rest.dropFirst() }
        else if rest.hasPrefix("//") || rest.hasPrefix("--") { rest = rest.dropFirst(2) }
        else { return nil }
        rest = rest.drop(while: { $0 == " " || $0 == "\t" })
        guard rest.hasPrefix("@") else { return nil }
        let key = rest.dropFirst().prefix(while: { !$0.isWhitespace })
        let value = rest.dropFirst(1 + key.count).trimmingCharacters(in: .whitespaces)
        return (String(key), value)
    }
}
