import Foundation
import ScrapbenchCore

/// `Scrapbench --transform <id>`: stdin through a prompt transformer to
/// stdout, no UI. The workflow bundle of a prompt with `@service` runs this.
/// `Scrapbench --set-key <anthropic|other>` stores the key read from stdin;
/// an item the app wrote itself is one the app can read without a prompt.
enum HeadlessTransform {
    static func setKey(account: String) -> Int32 {
        guard account == Settings.anthropicKeyAccount || account == Settings.otherKeyAccount else {
            return fail("unknown account \(account); use anthropic or other")
        }
        let key = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try Keychain.write(key, account: account)
            return 0
        } catch {
            return fail(error.localizedDescription)
        }
    }

    static func run(id: String) -> Int32 {
        guard !Distribution.isSandboxed else {
            return fail("not available in this build")
        }
        let scan = ScriptRegistry.scan(directory: Settings.transformersDirectory, scripts: false)
        guard let prompt = scan.prompts.first(where: { $0.id == id }) else {
            return fail("unknown transformer \(id)")
        }
        let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        let endpoint: PromptEndpoint
        switch PromptEndpoint.resolve(for: prompt, settings: Settings.shared.aiSettings()) {
        case .failure(let error): return fail("\(prompt.name): \(error.message)")
        case .success(let resolved): endpoint = resolved
        }
        let request = PromptRequest.build(endpoint: endpoint, systemPrompt: prompt.systemPrompt, input: input)
        let runner = PromptRunner(request: request, provider: endpoint.provider, timeout: prompt.timeout,
                                  callbackQueue: DispatchQueue(label: "org.nosenko.Scrapbench.headless"))
        let done = DispatchSemaphore(value: 0)
        var result: Result<String, TransformError> = .failure(TransformError("no result"))
        runner.start { result = $0; done.signal() }
        done.wait()
        switch result {
        case .failure(let error):
            return fail("\(prompt.name): \(error.message)")
        case .success(let text):
            FileHandle.standardOutput.write(Data(text.utf8))
            return 0
        }
    }

    private static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        return 1
    }
}
