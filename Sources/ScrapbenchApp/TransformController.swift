import AppKit
import ScrapbenchCore

/// Runs transformers on the editor's target text and reports problems in the banner.
/// Built-ins apply at once; script transformers run through `ScriptRunner`
/// and apply when the result arrives.
final class TransformController {
    static let lastKey = "lastTransformer"

    private let editor: EditorTextView
    private let banner: BannerView
    private let palette: PaletteController
    private let header: HeaderView
    private var extras: [any Transformer] = []
    private var pending: PendingTransform?
    private var runner: ScriptRunner?
    private var lastID: String? {
        get { UserDefaults.standard.string(forKey: Self.lastKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastKey) }
    }

    /// Appends a late script result as a new scrap and returns its range; set by the session.
    var onAppendResult: ((String) -> NSRange?)?

    var isRunning: Bool { pending != nil }

    /// The last applied transformer, if it still exists.
    var last: (any Transformer)? {
        guard let lastID else { return nil }
        let fromFolder = lastID.hasPrefix(ScriptTransformer.idPrefix) || lastID.hasPrefix(PromptTransformer.idPrefix)
        if fromFolder, extras.isEmpty { rescan(report: false) }
        return TransformerRegistry.transformer(id: lastID, extra: extras)
    }

    init(editor: EditorTextView, banner: BannerView, palette: PaletteController, header: HeaderView) {
        self.editor = editor
        self.banner = banner
        self.palette = palette
        self.header = header
        palette.onPick = { [weak self] in self?.run($0) }
        palette.onPickLast = { [weak self] in if let last = self?.last { self?.run(last) } }
        palette.onClose = { [weak header] in header?.isPaletteOpen = false }
        palette.onCancel = { [weak editor] in
            guard let editor else { return }
            let selection = editor.selectedRange()
            editor.setSelectedRange(NSRange(location: selection.upperBound, length: 0))
        }
    }

    func openPalette() {
        guard !palette.isOpen else { return }
        rescan(report: true)
        guard let items = candidates() else { return }
        header.isPaletteOpen = true
        palette.open(items: items, lastID: last?.id)
    }

    /// Transformers that apply to the current target, or nil (with a banner) when there is none.
    func candidates() -> [any Transformer]? {
        guard let target = editor.transformTarget() else {
            banner.flash("Nothing to transform")
            return nil
        }
        return TransformerRegistry.applicable(to: target.text, extra: extras)
    }

    func run(_ transformer: any Transformer) {
        guard let (range, text) = editor.transformTarget() else {
            banner.flash("Nothing to transform")
            return
        }
        if let script = transformer as? ScriptTransformer {
            start(script, range: range, text: text)
            return
        }
        do {
            let result = try transformer.apply(text)
            if result != text { editor.replace(range, with: result) }
            lastID = transformer.id
        } catch let error as TransformError {
            banner.flash("\(transformer.name): \(error.message)")
        } catch {
            banner.flash("\(transformer.name): \(error.localizedDescription)")
        }
    }

    /// The last transformer again if it applies to the current target, else the palette.
    func repeatLast() {
        palette.close()
        guard let transformer = last,
              let target = editor.transformTarget(), transformer.canApply(to: target.text) else {
            openPalette()
            return
        }
        run(transformer)
    }

    /// An edit is about to replace `range`; keeps the pending target in step.
    func textWillChange(in range: NSRange, replacement: String) {
        pending?.shift(edited: range, delta: (replacement as NSString).length - range.length)
    }

    /// Quit: the script is terminated and its result not awaited.
    func cancelRunning() {
        runner?.cancel()
        runner = nil
        pending = nil
        header.runningName = nil
    }

    // MARK: - Scripts

    private func rescan(report: Bool) {
        let scan = ScriptRegistry.scan(directory: Settings.transformersDirectory)
        extras = scan.transformers
        let problems = scan.problems
        guard report, !problems.isEmpty else { return }
        let list = problems.map { "\($0.file) (\($0.reason))" }.joined(separator: ", ")
        banner.flash("\(problems.count) \(problems.count == 1 ? "transformer" : "transformers") skipped: \(list)")
    }

    private func start(_ script: ScriptTransformer, range: NSRange, text: String) {
        if let pending {
            banner.flash("\(pending.name) is running")
            return
        }
        pending = PendingTransform(id: script.id, name: script.name, range: range, text: text)
        header.runningName = script.name
        let runner = ScriptRunner(script: script, input: text, scrapFile: Settings.shared.fileURL)
        self.runner = runner
        runner.start { [weak self] result in
            guard let self, self.runner === runner else { return }
            self.finish(result)
        }
    }

    private func finish(_ result: Result<String, TransformError>) {
        guard let pending else { return }
        self.pending = nil
        runner = nil
        header.runningName = nil
        switch result {
        case .failure(let error):
            banner.flash("\(pending.name): \(error.message)")
        case .success(let output):
            // Select the result only for a user who is still waiting on it; one
            // who moved on keeps the caret, or the next keystroke would eat it.
            let waiting = editor.selectedRange() == pending.range
            if editor.window?.isVisible == true, let range = pending.range,
               pending.isIntact(in: editor.string as NSString) {
                if output != pending.text { editor.replace(range, with: output, select: waiting) }
            } else if let range = onAppendResult?(output) {
                if waiting || editor.window?.isVisible != true { editor.setSelectedRange(range) }
                banner.flash("\(pending.name): text changed, result added below")
            } else {
                banner.flash("\(pending.name): result could not be added")
                return
            }
            lastID = pending.id
        }
    }
}
