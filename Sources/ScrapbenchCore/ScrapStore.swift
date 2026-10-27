import CryptoKit
import Foundation

public struct Snapshot: Equatable, Sendable {
    public let text: String
    /// SHA-256 hex of the file bytes; empty when the file does not exist.
    public let fingerprint: String

    public init(text: String, fingerprint: String) {
        self.text = text
        self.fingerprint = fingerprint
    }
}

public enum ScrapStoreError: Error, LocalizedError {
    case unreadable(URL, underlying: Error)
    case notUTF8(URL)
    case writeFailed(URL, underlying: Error)
    case externalChange(conflictURL: URL)

    public var errorDescription: String? {
        switch self {
        case let .unreadable(url, underlying):
            return "Can't read \(url.path): \(underlying.localizedDescription)"
        case let .notUTF8(url):
            return "\(url.path) is not UTF-8 text"
        case let .writeFailed(url, underlying):
            return "Can't write \(url.path): \(underlying.localizedDescription)"
        case let .externalChange(conflictURL):
            return "The file changed on disk. Your text was saved to \(conflictURL.lastPathComponent)"
        }
    }
}

/// File I/O for the single scrap file: atomic saves with external-change
/// detection, rescue copies for failed saves and a rolling daily backup.
public final class ScrapStore {
    public static let backupsToKeep = 7

    public let fileURL: URL
    public let supportDirectory: URL
    private let now: () -> Date
    private let fm = FileManager.default

    public init(fileURL: URL, supportDirectory: URL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.supportDirectory = supportDirectory
        self.now = now
    }

    public func load() throws -> Snapshot {
        guard let data = try readData() else { return Snapshot(text: "", fingerprint: "") }
        guard let text = String(data: data, encoding: .utf8) else { throw ScrapStoreError.notUTF8(fileURL) }
        return Snapshot(text: text, fingerprint: Self.fingerprint(of: data))
    }

    @discardableResult
    public func save(text: String, expecting: Snapshot) throws -> Snapshot {
        let onDisk = try readData().map(Self.fingerprint(of:)) ?? ""
        let data = Data(text.utf8)
        if onDisk != expecting.fingerprint {
            let conflictURL = fileURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(baseName).conflict-\(timestamp()).md")
            try write(data, to: conflictURL)
            throw ScrapStoreError.externalChange(conflictURL: conflictURL)
        }
        try write(data, to: fileURL)
        return Snapshot(text: text, fingerprint: Self.fingerprint(of: data))
    }

    @discardableResult
    public func writeRescue(text: String) throws -> URL {
        try fm.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let url = supportDirectory.appendingPathComponent("unsaved-\(timestamp()).md")
        try write(Data(text.utf8), to: url)
        return url
    }

    /// Copies the scrap file to `backups/<name>-<yyyy-MM-dd>.md` once per
    /// calendar day and keeps only the newest `backupsToKeep` copies.
    @discardableResult
    public func backupIfNeeded() throws -> URL? {
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        let dir = supportDirectory.appendingPathComponent("backups")
        let url = dir.appendingPathComponent("\(baseName)-\(dayStamp()).md")
        guard !fm.fileExists(atPath: url.path) else { return nil }
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fm.copyItem(at: fileURL, to: url)
        let backups = try fm.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("\(baseName)-") && $0.hasSuffix(".md") }
            .sorted()
        for stale in backups.dropLast(Self.backupsToKeep) {
            try fm.removeItem(at: dir.appendingPathComponent(stale))
        }
        return url
    }

    // MARK: - Helpers

    private var baseName: String { fileURL.deletingPathExtension().lastPathComponent }

    private func readData() throws -> Data? {
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        do { return try Data(contentsOf: fileURL) } catch { throw ScrapStoreError.unreadable(fileURL, underlying: error) }
    }

    private func write(_ data: Data, to url: URL) throws {
        do { try data.write(to: url, options: .atomic) } catch { throw ScrapStoreError.writeFailed(url, underlying: error) }
    }

    private static func fingerprint(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func timestamp() -> String { Self.format(now(), "yyyyMMdd-HHmmss") }
    private func dayStamp() -> String { Self.format(now(), "yyyy-MM-dd") }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: date)
    }
}
