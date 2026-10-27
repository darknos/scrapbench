import AppKit
import Combine
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.control, .option]))
}

final class Settings: ObservableObject {
    static let shared = Settings()

    static let defaultFileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("scrapbench.md")
    static let supportDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Scrapbench")

    @Published var fileURL: URL { didSet { defaults.set(fileURL.path, forKey: "filePath") } }
    @Published var fontName: String { didSet { defaults.set(fontName, forKey: "fontName") } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: "fontSize") } }

    private let defaults = UserDefaults.standard

    private init() {
        fileURL = defaults.string(forKey: "filePath").map { URL(fileURLWithPath: $0) } ?? Self.defaultFileURL
        fontName = defaults.string(forKey: "fontName") ?? "Menlo"
        let size = defaults.double(forKey: "fontSize")
        fontSize = size > 0 ? size : 14
    }

    /// Pseudo family for the system monospaced font, which has no public family name.
    static let systemMonoFamily = "System Mono"

    static let monospacedFamilies: [String] = {
        let manager = NSFontManager.shared
        let families = manager.availableFontFamilies.filter { family in
            guard let font = manager.font(withFamily: family, traits: [], weight: 5, size: 12) else { return false }
            return font.isFixedPitch && !family.hasPrefix(".")
        }
        return [systemMonoFamily] + families.sorted()
    }()

    var font: NSFont {
        if fontName == Self.systemMonoFamily { return .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
        return NSFontManager.shared.font(withFamily: fontName, traits: [], weight: 5, size: fontSize)
            ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}
