import AppKit
import Combine
import ScrapbenchCore

/// Owns the open → edit → close flow of the panel for one scrap file.
final class SessionController: NSObject, NSTextViewDelegate {
    static let autosaveDelay: TimeInterval = 2

    private let panel = BenchPanel()
    private let settings = Settings.shared
    private var store: ScrapStore
    private var formatter = ScrapFormatter()
    private var snapshot = Snapshot(text: "", fingerprint: "")
    private var autosave: Timer?
    private var saveBlocked = false
    private var closing = false
    private var fontObserver: AnyCancellable?
    private(set) var transform: TransformController!

    private var editor: EditorTextView { panel.editor }
    private var text: String { editor.string }

    override init() {
        store = ScrapStore(fileURL: settings.fileURL, supportDirectory: Settings.supportDirectory)
        super.init()
        transform = TransformController(editor: editor, banner: panel.banner, palette: panel.palette, header: panel.header)
        panel.header.onTransform = { [weak self] in self?.transform.openPalette() }
        editor.delegate = self
        editor.onEscape = { [weak self] in self?.close() }
        editor.onNewScrap = { [weak self] in self?.newScrap() }
        editor.onSave = { [weak self] in self?.saveNow(force: true) }
        editor.onKeyDown = { [weak self] in self?.panel.banner.dismissFlash() }
        editor.onTransform = { [weak self] in self?.transform.openPalette() }
        editor.onRepeatTransform = { [weak self] in self?.transform.repeatLast() }
        panel.onClose = { [weak self] in self?.close() }
        panel.onFocusLost = { [weak self] in self?.saveNow() }
        fontObserver = settings.$fontName.combineLatest(settings.$fontSize)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.editor.applyFont(self.settings.font)
            }
    }

    func toggle() {
        if !panel.isVisible {
            open()
        } else if panel.isKeyWindow {
            close()
        } else {
            panel.show()
        }
    }

    func open() {
        guard !panel.isVisible else { return }
        store = ScrapStore(fileURL: settings.fileURL, supportDirectory: Settings.supportDirectory)
        panel.title = settings.fileURL.lastPathComponent
        panel.header.fileName = settings.fileURL.lastPathComponent
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
            panel.header.status = "read-only"
            panel.show()
            panel.banner.show(error.localizedDescription, buttonTitle: "Open Settings") {
                NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
            }
            return
        }

        let modified = (try? settings.fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        panel.header.status = Self.savedStatus(at: modified)
        formatter = ScrapFormatter()
        let opened = formatter.open(text: snapshot.text, date: Date())
        editor.load(opened.text)
        panel.show()
        editor.moveToEnd()
    }

    func newScrap() {
        guard editor.isEditable else { return }
        let result = formatter.newScrap(text: text, date: Date())
        editor.replaceTail(with: result.text)
        editor.revealEnd()
        scheduleAutosave()
    }

    /// Text handed over by the "Take to Scrapbench" service: lands at the end
    /// of the file on its own line, in the scrap this open created.
    func take(text: String) {
        if !panel.isVisible { open() } else { panel.show() }
        guard editor.isEditable else { return }
        let result = ScrapFormatter.append(chunk: text, to: self.text)
        guard result != self.text else { return }
        editor.replaceTail(with: result)
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
            panel.header.status = Self.savedStatus(at: Date())
            return true
        } catch ScrapStoreError.externalChange(let conflictURL) {
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

    /// Flushes pending edits immediately, e.g. when focus moves to another app.
    /// `force` writes even when nothing is pending (explicit ⌘S).
    private func saveNow(force: Bool = false) {
        guard force || autosave != nil, !saveBlocked, panel.isVisible else { return }
        autosave?.invalidate()
        autosave = nil
        persist(text)
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func savedStatus(at date: Date?) -> String {
        date.map { "saved " + clock.string(from: $0) } ?? "saved"
    }

    private func scheduleAutosave() {
        guard !saveBlocked else { return }
        panel.header.status = "editing"
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
