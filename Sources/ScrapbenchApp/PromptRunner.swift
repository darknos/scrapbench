import Foundation
import os
import ScrapbenchCore

/// What the controller holds while a transformer runs outside `apply`.
protocol TransformRunner: AnyObject {
    func cancel()
}

extension ScriptRunner: TransformRunner {}

/// Runs one prompt transformer: a request built by Core, the answer parsed
/// by Core. The completion runs on `callbackQueue` exactly once, unless cancelled.
final class PromptRunner: TransformRunner {
    private static let log = Logger(subsystem: "org.nosenko.Scrapbench", category: "prompt")

    private let request: URLRequest
    private let provider: PromptProvider
    private let timeout: Int
    private let callbackQueue: DispatchQueue
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var cancelled = false

    init(request: URLRequest, provider: PromptProvider, timeout: Int, callbackQueue: DispatchQueue = .main) {
        self.request = request
        self.provider = provider
        self.timeout = timeout
        self.callbackQueue = callbackQueue
    }

    func start(completion: @escaping (Result<String, TransformError>) -> Void) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = TimeInterval(timeout)
        configuration.timeoutIntervalForResource = TimeInterval(timeout)
        let session = URLSession(configuration: configuration)
        self.session = session
        let provider = provider
        let timeout = timeout
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            session.finishTasksAndInvalidate()
            let result = Self.verdict(provider: provider, timeout: timeout, data: data, response: response, error: error)
            self?.callbackQueue.async {
                guard let self, !self.cancelled else { return }
                completion(result)
            }
        }
        self.task = task
        task.resume()
    }

    func cancel() {
        cancelled = true
        task?.cancel()
        session?.invalidateAndCancel()
    }

    private static func verdict(provider: PromptProvider, timeout: Int, data: Data?, response: URLResponse?,
                                error: Error?) -> Result<String, TransformError> {
        if let error {
            let code = (error as? URLError)?.code ?? .unknown
            return .failure(TransformError(PromptResponse.message(forURLError: code, timeout: timeout)))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = data ?? Data()
        let result = PromptResponse.parse(provider: provider, status: status, data: body)
        if case .failure = result, !(200..<300).contains(status) || result == .failure(TransformError("bad response")) {
            let text = String(decoding: body.prefix(4096), as: UTF8.self)
            log.error("status \(status, privacy: .public): \(text, privacy: .public)")
        }
        return result
    }
}
