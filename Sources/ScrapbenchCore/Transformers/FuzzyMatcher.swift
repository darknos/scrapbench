import Foundation

public enum FuzzyMatcher {
    /// nil when `query` is not a case-insensitive subsequence of `candidate`.
    /// Greedy left-to-right match; +3 for a match at a word start, +2 right
    /// after the previous match, +1 otherwise, minus the index of the first
    /// match and the characters skipped between matches. Higher is better.
    public static func score(query: String, candidate: String) -> Int? {
        let needle = Array(query.lowercased())
        let haystack = Array(candidate.lowercased())
        guard !needle.isEmpty else { return 0 }
        var score = 0
        var position = 0
        var previousMatch: Int?
        for character in needle {
            guard let index = haystack[position...].firstIndex(of: character) else { return nil }
            let wordStart = index == 0 || !(haystack[index - 1].isLetter || haystack[index - 1].isNumber)
            if let previous = previousMatch {
                score += index == previous + 1 ? 2 : (wordStart ? 3 : 1)
                score -= index - previous - 1
            } else {
                score += wordStart ? 3 : 1
                score -= index
            }
            previousMatch = index
            position = index + 1
        }
        return score
    }

    /// Items whose name matches, best score first; original order for ties.
    public static func rank<T>(_ items: [T], query: String, name: (T) -> String) -> [T] {
        items.enumerated()
            .compactMap { offset, item in score(query: query, candidate: name(item)).map { (offset, item, $0) } }
            .sorted { a, b in a.2 != b.2 ? a.2 > b.2 : a.0 < b.0 }
            .map { $0.1 }
    }
}
