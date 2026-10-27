import Foundation
import Testing
@testable import ScrapbenchCore

@Suite struct NoteStoreTests {
    let dir: URL
    let file: URL
    let support: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("NoteStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("daily-notes.md")
        support = dir.appendingPathComponent("support")
    }

    func store(now: @escaping () -> Date = Date.init) -> NoteStore {
        NoteStore(fileURL: file, supportDirectory: support, now: now)
    }

    func listing(_ url: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
    }

    @Test func loadMissingFileIsEmpty() throws {
        #expect(try store().load() == Snapshot(text: "", fingerprint: ""))
    }

    @Test func saveThenLoadRoundTrips() throws {
        let s = store()
        let text = "привет 🙂\n```json\n{}\n```\n"
        let snap = try s.save(text: text, expecting: try s.load())
        let loaded = try s.load()
        #expect(loaded.text == text)
        #expect(loaded == snap)
        #expect(!snap.fingerprint.isEmpty)
    }

    @Test func saveLeavesNoTempFiles() throws {
        let s = store()
        try s.save(text: "a\n", expecting: try s.load())
        #expect(try listing(dir) == ["daily-notes.md"])
    }

    @Test func saveSucceedsWhenDiskMatchesSnapshot() throws {
        let s = store()
        let snap = try s.save(text: "a\n", expecting: try s.load())
        try Data("a\n".utf8).write(to: file)   // sync rewrote identical bytes
        try s.save(text: "a\nb\n", expecting: snap)
        #expect(try s.load().text == "a\nb\n")
    }

    @Test func saveDetectsExternalChange() throws {
        let s = store()
        let snap = try s.save(text: "a\n", expecting: try s.load())
        try Data("changed\n".utf8).write(to: file)
        #expect(throws: NoteStoreError.self) {
            try s.save(text: "a\nmine\n", expecting: snap)
        }
        let files = try listing(dir)
        #expect(files.count == 2)
        let conflict = try #require(files.first { $0.hasPrefix("daily-notes.conflict-") && $0.hasSuffix(".md") })
        #expect(try String(contentsOf: dir.appendingPathComponent(conflict), encoding: .utf8) == "a\nmine\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "changed\n")
    }

    @Test func rescueWritesToSupportDir() throws {
        let url = try store().writeRescue(text: "rescued\n")
        #expect(url.deletingLastPathComponent().path == support.path)
        #expect(url.lastPathComponent.hasPrefix("unsaved-"))
        #expect(try String(contentsOf: url, encoding: .utf8) == "rescued\n")
    }

    @Test func backupOncePerDay() throws {
        let now = localDate(2026, 10, 26, 10, 0)
        let s = store(now: { now })
        try s.save(text: "a\n", expecting: try s.load())
        let first = try s.backupIfNeeded()
        #expect(first?.lastPathComponent == "daily-notes-2026-10-26.md")
        #expect(try s.backupIfNeeded() == nil)
        #expect(try listing(support.appendingPathComponent("backups")) == ["daily-notes-2026-10-26.md"])
    }

    @Test func backupPrunesToSeven() throws {
        try Data("a\n".utf8).write(to: file)
        for day in 1...9 {
            _ = try store(now: { localDate(2026, 10, day, 10, 0) }).backupIfNeeded()
        }
        let files = try listing(support.appendingPathComponent("backups"))
        #expect(files.count == 7)
        #expect(files.first == "daily-notes-2026-10-03.md")
        #expect(files.last == "daily-notes-2026-10-09.md")
    }

    @Test func backupSkipsMissingFile() throws {
        #expect(try store().backupIfNeeded() == nil)
        #expect(!FileManager.default.fileExists(atPath: support.path))
    }

    @Test func loadRejectsNonUTF8() throws {
        try Data([0xFF, 0xFE, 0x00, 0xD8]).write(to: file)
        #expect(throws: NoteStoreError.self) { try store().load() }
    }
}
