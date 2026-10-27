import AppKit
import Combine
import DailyNotesCore

/// Owns the open → edit → close flow of the panel for one notes file.
final class SessionController: NSObject, NSTextViewDelegate {
    static let autosaveDelay: TimeInterval = 2

    private let panel = NotePanel()
    private let settings = Settings.shared
    private var store: NoteStore
    private var formatter = EntryFormatter()
    private var snapshot = Snapshot(text: "", fingerprint: "")
    private var autosave: Timer?
    private var saveBlocked = false
    private var closing = false
    private var fontObserver: AnyCancellable?

    private var editor: EditorTextView { panel.editor }
    private var text: String { editor.string }

    override init() {
        store = NoteStore(fileURL: settings.fileURL, supportDirectory: Settings.supportDirectory)
        super.init()
        editor.delegate = self
        editor.onEscape = { [weak self] in self?.close() }
        editor.onNewEntry = { [weak self] in self?.newEntry() }
        panel.onClose = { [weak self] in self?.close() }
        fontObserver = settings.$fontName.combineLatest(settings.$fontSize)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.editor.applyFont(self.settings.font)
            }
    }

    func toggle() {
        panel.isVisible ? close() : open()
    }

    func open() {
        guard !panel.isVisible else { return }
        store = NoteStore(fileURL: settings.fileURL, supportDirectory: Settings.supportDirectory)
        editor.font = settings.font
        saveBlocked = false
        editor.isEditable = true

        do { try store.backupIfNeeded() } catch { NSLog("backup failed: \(error)") }

        do {
            snapshot = try store.load()
        } catch {
            snapshot = Snapshot(text: "", fingerprint: "")
            editor.load("")
            editor.isEditable = false
            saveBlocked = true
            panel.show()
            panel.banner.show(error.localizedDescription, buttonTitle: "Open Settings") {
                NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
            }
            return
        }

        formatter = EntryFormatter()
        let opened = formatter.open(text: snapshot.text, date: Date())
        editor.load(opened.text)
        panel.show()
        editor.moveToEnd()
    }

    func newEntry() {
        guard editor.isEditable else { return }
        let result = formatter.newEntry(text: text, date: Date())
        editor.replaceTail(with: result.text)
        editor.revealEnd()
        scheduleAutosave()
    }

    func close() {
        guard panel.isVisible, !closing else { return }
        closing = true
        defer { closing = false }
        autosave?.invalidate()
        autosave = nil

        if saveBlocked {
            panel.orderOut(nil)
            return
        }
        let final = formatter.finalize(text: text)
        if final != snapshot.text {
            guard persist(final) else { return }
        }
        panel.orderOut(nil)
    }

    // MARK: - Saving

    /// Returns false when the text could not be written; the panel must stay open then.
    @discardableResult
    private func persist(_ content: String) -> Bool {
        do {
            snapshot = try store.save(text: content, expecting: snapshot)
            panel.banner.isHidden = true
            return true
        } catch NoteStoreError.externalChange(let conflictURL) {
            saveBlocked = true
            panel.banner.show("File changed on disk. Your text is in \(conflictURL.lastPathComponent)",
                              buttonTitle: "Reveal") {
                NSWorkspace.shared.activateFileViewerSelecting([conflictURL])
            }
            return false
        } catch {
            let rescue = try? store.writeRescue(text: content)
            let suffix = rescue.map { " Copy saved to \($0.lastPathComponent)." } ?? ""
            panel.banner.show(error.localizedDescription + suffix, buttonTitle: "Open Settings") {
                NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
            }
            return false
        }
    }

    private func scheduleAutosave() {
        guard !saveBlocked else { return }
        autosave?.invalidate()
        autosave = Timer.scheduledTimer(withTimeInterval: Self.autosaveDelay, repeats: false) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            self.persist(self.text)
        }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        scheduleAutosave()
    }
}
