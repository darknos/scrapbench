import Foundation

/// One level of indentation at a time, as Tab and Shift-Tab do in editors.
/// `unit` is what one level is made of: spaces or a single tab.
public enum Indentation {
    public static func indent(_ text: String, unit: String) -> String {
        map(text) { lines in lines.map { $0.isEmpty ? $0 : unit + $0 } }
    }

    /// Removes a leading tab, or up to one unit of spaces (four when the unit is a tab).
    public static func outdent(_ text: String, unit: String) -> String {
        let width = unit == "\t" ? 4 : unit.count
        return map(text) { lines in
            lines.map { line in
                if line.hasPrefix("\t") { return String(line.dropFirst()) }
                let leading = line.prefix(while: { $0 == " " }).count
                return String(line.dropFirst(min(leading, width)))
            }
        }
    }

    private static func map(_ text: String, _ transform: ([String]) -> [String]) -> String {
        let trailing = text.hasSuffix("\n")
        var lines = text.components(separatedBy: "\n")
        if trailing { lines.removeLast() }
        return transform(lines).joined(separator: "\n") + (trailing ? "\n" : "")
    }
}
