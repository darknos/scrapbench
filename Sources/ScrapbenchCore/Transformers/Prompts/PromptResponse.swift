import Foundation

/// Turns an HTTP status and body from either provider into the answer text
/// or a short lower-case error for the banner.
public enum PromptResponse {
    static let messageLimit = 80

    public static func parse(provider: PromptProvider, status: Int, data: Data) -> Result<String, TransformError> {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200..<300).contains(status) else {
            return .failure(TransformError(statusMessage(status, json: json)))
        }
        guard let json else { return .failure(TransformError("bad response")) }
        let text: String
        switch provider {
        case .anthropic:
            switch json["stop_reason"] as? String {
            case "refusal": return .failure(TransformError("refused"))
            case "max_tokens": return .failure(TransformError("output too long"))
            default: break
            }
            guard let content = json["content"] as? [[String: Any]] else { return .failure(TransformError("bad response")) }
            text = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        case .other:
            guard let choice = (json["choices"] as? [[String: Any]])?.first,
                  let message = choice["message"] as? [String: Any] else {
                return .failure(TransformError("bad response"))
            }
            switch choice["finish_reason"] as? String {
            case "length": return .failure(TransformError("output too long"))
            case "content_filter": return .failure(TransformError("refused"))
            default: break
            }
            if let string = message["content"] as? String {
                text = string
            } else if let parts = message["content"] as? [[String: Any]] {
                text = parts.compactMap { $0["text"] as? String }.joined()
            } else if message["refusal"] is String {
                return .failure(TransformError("refused"))
            } else {
                return .failure(TransformError("bad response"))
            }
        }
        let answer = trimmed(text)
        return answer.isEmpty ? .failure(TransformError("empty output")) : .success(answer)
    }

    /// Removes trailing line breaks only; the answer's own spacing is kept.
    /// Works on scalars because `\r\n` is one `Character`.
    public static func trimmed(_ text: String) -> String {
        var scalars = text.unicodeScalars
        while let last = scalars.last, last == "\n" || last == "\r" { scalars.removeLast() }
        return String(scalars)
    }

    public static func message(forURLError code: URLError.Code, timeout: Int) -> String {
        switch code {
        case .timedOut: return "timed out after \(timeout) s"
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "offline"
        case .cancelled: return "cancelled"
        case .appTransportSecurityRequiresSecureConnection: return "http needs https" + PromptEndpoint.settingsHint
        default: return URLError(code).localizedDescription.lowercased()
        }
    }

    private static func statusMessage(_ status: Int, json: [String: Any]?) -> String {
        switch status {
        case 401: return "401 invalid api key"
        case 403: return "403 not allowed"
        case 404: return "404 unknown model or URL"
        case 429: return "rate limited"
        case 503, 529: return "overloaded"
        default:
            // Anthropic and OpenAI nest an object under `error`; Ollama and LM Studio send a string.
            let error = json?["error"] as? [String: Any]
            let detail = (error?["message"] as? String) ?? (error?["type"] as? String)
                ?? (json?["error"] as? String) ?? "error"
            return "\(status) " + String(detail.prefix(messageLimit)).lowercased()
        }
    }
}
