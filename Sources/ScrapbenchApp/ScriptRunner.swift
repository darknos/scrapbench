import Foundation
import ScrapbenchCore

/// Runs one script transformer: input on stdin, stdout as the result.
/// The completion runs on the main thread exactly once, unless cancelled.
final class ScriptRunner {
    static let killGrace: TimeInterval = 2

    private let script: ScriptTransformer
    private let input: String
    private let scrapFile: URL
    private let process = Process()
    private let queue = DispatchQueue(label: "org.nosenko.Scrapbench.script")
    private var stdout = Data()
    private var stderr = Data()
    private var timedOut = false
    private var cancelled = false
    private var timeoutWork: DispatchWorkItem?

    init(script: ScriptTransformer, input: String, scrapFile: URL) {
        self.script = script
        self.input = input
        self.scrapFile = scrapFile
    }

    func start(completion: @escaping (Result<String, TransformError>) -> Void) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        process.executableURL = script.url
        process.currentDirectoryURL = URL(fileURLWithPath: home)
        process.environment = [
            "HOME": home,
            "USER": NSUserName(),
            "LANG": "en_US.UTF-8",
            "PATH": "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
            "SCRAPBENCH_FILE": scrapFile.path,
        ]
        let stdinPipe = Pipe(), stdoutPipe = Pipe(), stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Both readers signal EOF before the verdict, so the output is complete
        // even when the child exits before the pipes drain.
        let drained = DispatchGroup()
        drained.enter(); drained.enter()
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.collect(handle.availableData, into: \.stdout, handle: handle, done: drained)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.collect(handle.availableData, into: \.stderr, handle: handle, done: drained)
        }

        process.terminationHandler = { [weak self] process in
            drained.notify(queue: .main) {
                guard let self, !self.cancelled else { return }
                self.timeoutWork?.cancel()
                completion(self.verdict(status: process.terminationStatus))
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { completion(.failure(TransformError(error.localizedDescription))) }
            return
        }

        let data = Data(input.utf8)
        DispatchQueue.global(qos: .userInitiated).async {
            try? stdinPipe.fileHandleForWriting.write(contentsOf: data)
            try? stdinPipe.fileHandleForWriting.close()
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.process.isRunning else { return }
            self.timedOut = true
            self.terminate()
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(script.timeout), execute: work)
    }

    /// SIGTERM now, SIGKILL after the grace period; the completion is not called.
    func cancel() {
        cancelled = true
        timeoutWork?.cancel()
        terminate()
    }

    private func terminate() {
        guard process.isRunning else { return }
        process.terminate()
        let process = self.process
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.killGrace) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    private func collect(_ data: Data, into key: ReferenceWritableKeyPath<ScriptRunner, Data>,
                         handle: FileHandle, done: DispatchGroup) {
        if data.isEmpty {
            // EOF: the handler keeps firing until it is cleared, so clear it
            // here, on the handle's own queue, and leave the group once.
            handle.readabilityHandler = nil
            queue.async { done.leave() }
        } else {
            queue.async { self[keyPath: key].append(data) }
        }
    }

    private func verdict(status: Int32) -> Result<String, TransformError> {
        if timedOut { return .failure(TransformError("timed out after \(script.timeout) s")) }
        if status != 0 {
            let line = String(decoding: stderr, as: UTF8.self)
                .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }
            return .failure(TransformError(line ?? "exit code \(status)"))
        }
        if stdout.isEmpty { return .failure(TransformError("empty output")) }
        guard let text = String(data: stdout, encoding: .utf8) else {
            return .failure(TransformError("invalid UTF-8 output"))
        }
        return .success(text)
    }
}
