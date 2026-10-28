import Foundation

public enum ScriptRegistry {
    /// Every executable regular file directly in `directory` with a valid
    /// header, ordered by group name then file name; the rest as problems.
    /// Dot files, folders and a missing directory are silently skipped.
    public static func scan(directory: URL) -> (transformers: [ScriptTransformer], problems: [ScriptProblem]) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isExecutableKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return ([], [])
        }
        var transformers: [ScriptTransformer] = []
        var problems: [ScriptProblem] = []
        var seen: Set<String> = []
        for url in entries.sorted(by: { Array($0.lastPathComponent.utf8).lexicographicallyPrecedes(Array($1.lastPathComponent.utf8)) }) {
            let file = url.lastPathComponent
            guard !file.hasPrefix("."), let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
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
                transformers.append(script)
            }
        }
        transformers.sort {
            ($0.group.name, $0.url.lastPathComponent) < ($1.group.name, $1.url.lastPathComponent)
        }
        return (transformers, problems)
    }
}
