import Foundation

/// The target of a script transformer while the script runs: where it was
/// and what it said, kept in step with edits so a late result can tell
/// whether it still fits.
public struct PendingTransform: Sendable {
    public let id: String
    public let name: String
    /// nil once an edit overlapped the target.
    public private(set) var range: NSRange?
    public let text: String

    public init(id: String, name: String, range: NSRange, text: String) {
        self.id = id
        self.name = name
        self.range = range
        self.text = text
    }

    /// An edit replaced `edited` (the old range) with `delta` more UTF-16 units.
    public mutating func shift(edited: NSRange, delta: Int) {
        guard let current = range else { return }
        if edited.upperBound <= current.location {
            range = NSRange(location: current.location + delta, length: current.length)
        } else if edited.location >= current.upperBound {
            return
        } else {
            range = nil
        }
    }

    /// The remembered range still holds the remembered text.
    public func isIntact(in storage: NSString) -> Bool {
        guard let range, range.upperBound <= storage.length else { return false }
        return storage.substring(with: range) == text
    }
}
