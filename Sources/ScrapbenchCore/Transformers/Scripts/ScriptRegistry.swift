import Foundation

/// What one scan of the transformers folder found.
public struct ScanResult {
    public let scripts: [ScriptTransformer]
    public let prompts: [PromptTransformer]
    public let problems: [ScriptProblem]

    public init(scripts: [ScriptTransformer], prompts: [PromptTransformer], problems: [ScriptProblem]) {
        self.scripts = scripts
        self.prompts = prompts
        self.problems = problems
    }

    /// Scripts and prompts together, by group name then file name.
    public var transformers: [any Transformer] {
        let keyed: [(group: String, file: String, item: any Transformer)] =
            scripts.map { ($0.group.name, $0.url.lastPathComponent, $0) }
            + prompts.map { ($0.group.name, $0.url.lastPathComponent, $0) }
        return keyed.sorted { ($0.group, $0.file) < ($1.group, $1.file) }.map(\.item)
    }
}

public enum ScriptRegistry {
    /// Every executable regular file directly in `directory` with a valid
    /// header, plus every `.prompt` file (executable or not); the rest as
    /// problems. Dot files, folders and a missing directory are silently
    /// skipped; a symlink counts as the file it points to, under the link's
    /// name. With `scripts: false` only prompt files are read and other
    /// files are neither listed nor reported.
    public static func scan(directory: URL, scripts: Bool = true) -> ScanResult {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isExecutableKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return ScanResult(scripts: [], prompts: [], problems: [])
        }
        var found: [ScriptTransformer] = []
        var prompts: [PromptTransformer] = []
        var problems: [ScriptProblem] = []
        var seen: Set<String> = []
        for url in entries.sorted(by: { Array($0.lastPathComponent.utf8).lexicographicallyPrecedes(Array($1.lastPathComponent.utf8)) }) {
            let file = url.lastPathComponent
            guard !file.hasPrefix("."),
                  let values = try? url.resolvingSymlinksInPath().resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            if url.pathExtension == PromptFile.fileExtension {
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                switch PromptFile.parse(text, file: file) {
                case .failure(let problem):
                    problems.append(problem)
                case .success(let parsed):
                    let prompt = PromptTransformer(header: parsed.header, body: parsed.body, url: url)
                    guard seen.insert(prompt.id).inserted else {
                        problems.append(ScriptProblem(file: file, reason: "duplicate id"))
                        continue
                    }
                    prompts.append(prompt)
                }
                continue
            }
            guard scripts else { continue }
            guard values.isExecutable == true else {
                problems.append(ScriptProblem(file: file, reason: "not executable"))
                continue
            }
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            switch ScriptHeader.parse(text, file: file) {
            case .failure(let problem):
                problems.append(problem)
            case .success(let header):
                let script = ScriptTransformer(header: header, url: url)
                guard seen.insert(script.id).inserted else {
                    problems.append(ScriptProblem(file: file, reason: "duplicate id"))
                    continue
                }
                found.append(script)
            }
        }
        found.sort { ($0.group.name, $0.url.lastPathComponent) < ($1.group.name, $1.url.lastPathComponent) }
        prompts.sort { ($0.group.name, $0.url.lastPathComponent) < ($1.group.name, $1.url.lastPathComponent) }
        return ScanResult(scripts: found, prompts: prompts, problems: problems)
    }
}
