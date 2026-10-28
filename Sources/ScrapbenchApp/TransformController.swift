import AppKit
import ScrapbenchCore

/// Runs transformers on the editor's target text and reports problems in the banner.
final class TransformController {
    static let lastKey = "lastTransformer"

    private let editor: EditorTextView
    private let banner: BannerView
    private let palette: PaletteController
    private let header: HeaderView
    private var lastID: String? {
        get { UserDefaults.standard.string(forKey: Self.lastKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastKey) }
    }

    /// The last applied transformer, if it still exists.
    var last: (any Transformer)? { lastID.flatMap(TransformerRegistry.transformer(id:)) }

    init(editor: EditorTextView, banner: BannerView, palette: PaletteController, header: HeaderView) {
        self.editor = editor
        self.banner = banner
        self.palette = palette
        self.header = header
        palette.onPick = { [weak self] in self?.run($0) }
        palette.onPickLast = { [weak self] in if let last = self?.last { self?.run(last) } }
        palette.onClose = { [weak header] in header?.isPaletteOpen = false }
    }

    func openPalette() {
        guard !palette.isOpen, let items = candidates() else { return }
        header.isPaletteOpen = true
        palette.open(items: items, lastID: last?.id)
    }

    /// Transformers that apply to the current target, or nil (with a banner) when there is none.
    func candidates() -> [any Transformer]? {
        guard let target = editor.transformTarget() else {
            banner.flash("Nothing to transform")
            return nil
        }
        return TransformerRegistry.applicable(to: target.text)
    }

    func run(_ transformer: any Transformer) {
        guard let (range, text) = editor.transformTarget() else {
            banner.flash("Nothing to transform")
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
        guard let transformer = last,
              let target = editor.transformTarget(), transformer.canApply(to: target.text) else {
            openPalette()
            return
        }
        run(transformer)
    }
}
