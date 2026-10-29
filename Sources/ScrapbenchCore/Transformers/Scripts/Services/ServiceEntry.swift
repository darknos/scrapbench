import Foundation

/// One transformer offered as a macOS Service: what the workflow bundle
/// needs to know, whether the source is a script or a prompt.
public struct ServiceEntry: Equatable, Sendable {
    public let id: String
    public let name: String
    /// The source file, for people reading the bundle.
    public let path: String
    /// The shell lines the bundle's Run Shell Script action executes.
    public let command: String

    public init(id: String, name: String, path: String, command: String) {
        self.id = id
        self.name = name
        self.path = path
        self.command = command
    }

    public static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public extension ScriptTransformer {
    var serviceEntry: ServiceEntry {
        ServiceEntry(id: id, name: name, path: url.path, command: """
            export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            export LANG=en_US.UTF-8
            exec \(ServiceEntry.shellQuoted(url.path))
            """)
    }
}

public extension PromptTransformer {
    /// A prompt cannot be executed, so the bundle runs the app headless.
    func serviceEntry(executable: String) -> ServiceEntry {
        ServiceEntry(id: id, name: name, path: url.path, command: """
            export LANG=en_US.UTF-8
            exec \(ServiceEntry.shellQuoted(executable)) --transform \(id)
            """)
    }
}
