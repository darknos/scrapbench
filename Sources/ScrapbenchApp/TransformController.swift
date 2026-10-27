import AppKit
import ScrapbenchCore

/// Runs transformers on the editor's target text and reports problems in the banner.
final class TransformController {
    private let editor: EditorTextView
    private let banner: BannerView
    private var lastID: String?
    private var palette: CommandPalette?

    init(editor: EditorTextView, banner: BannerView) {
        self.editor = editor
        self.banner = banner
    }

    func openPalette() {
        guard palette == nil, let window = editor.window, let items = candidates() else { return }
        let palette = CommandPalette(parent: window, items: items,
                                     onPick: { [weak self] in self?.run($0) },
                                     onClose: { [weak self] in self?.palette = nil })
        self.palette = palette
        palette.show()
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
        guard let lastID, let transformer = TransformerRegistry.transformer(id: lastID),
              let target = editor.transformTarget(), transformer.canApply(to: target.text) else {
            openPalette()
            return
        }
        run(transformer)
    }
}
