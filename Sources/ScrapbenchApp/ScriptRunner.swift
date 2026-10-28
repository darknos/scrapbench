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
    private var stdoutPipe = Pipe()
    private var stderrPipe = Pipe()
    private var stdout = Data()
    private var stderr = Data()
    private var timedOut = false
    private var cancelled = false
    private var finished = false
    private var completion: ((Result<String, TransformError>) -> Void)?
    private var timeoutWork: DispatchWorkItem?

    init(script: ScriptTransformer, input: String, scrapFile: URL) {
        self.script = script
        self.input = input
        self.scrapFile = scrapFile
    }

    func start(completion: @escaping (Result<String, TransformError>) -> Void) {
        self.completion = completion
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
        let stdinPipe = Pipe()
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
                self?.finish(status: process.terminationStatus)
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { [self] in deliver(.failure(TransformError(error.localizedDescription))) }
            return
        }

        // A script that exits without reading its input would otherwise kill
        // the app with SIGPIPE on the blocked write.
        let writer = stdinPipe.fileHandleForWriting
        _ = fcntl(writer.fileDescriptor, F_SETNOSIGPIPE, 1)
        let data = Data(input.utf8)
        DispatchQueue.global(qos: .userInitiated).async {
            try? writer.write(contentsOf: data)
            try? writer.close()
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.finished else { return }
            self.timedOut = self.process.isRunning
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

    /// Signals the script's whole process group (Foundation gives the child
    /// its own), so children it spawned go too. After the grace period the
    /// group gets SIGKILL and the verdict is delivered without waiting for
    /// pipes a stray child may still hold.
    private func terminate() {
        let pgid = process.processIdentifier
        guard pgid > 0 else { return }
        kill(-pgid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.killGrace) { [weak self] in
            kill(-pgid, SIGKILL)
            guard let self, !self.finished else { return }
            self.finish(status: self.process.isRunning ? -1 : self.process.terminationStatus)
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

    private func finish(status: Int32) {
        guard !finished else { return }
        finished = true
        timeoutWork?.cancel()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()
        queue.sync {}  // appends queued before EOF land before the verdict reads the buffers
        deliver(verdict(status: status))
    }

    private func deliver(_ result: Result<String, TransformError>) {
        guard !cancelled, let completion else { return }
        self.completion = nil
        completion(result)
    }

    private func verdict(status: Int32) -> Result<String, TransformError> {
        if timedOut { return .failure(TransformError("timed out after \(script.timeout) s")) }
        if status != 0 {
            let line = String(decoding: stderr, as: UTF8.self)
                .split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
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
