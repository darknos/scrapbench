import Foundation

/// Where a prompt transformer sends its request.
public enum PromptProvider: String, CaseIterable, Sendable {
    case anthropic
    case other
}

/// `output_config.effort` of the Anthropic Messages API.
public enum Effort: String, CaseIterable, Sendable {
    case low, medium, high, xhigh, max
}
