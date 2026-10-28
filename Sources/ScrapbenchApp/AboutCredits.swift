import AppKit

enum AboutCredits {
    static let author = "Sergey Nosenko"
    static let email = "sergey@nosenko.org"
    static let repository = "https://github.com/darknos/scrapbench"

    static var text: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let result = NSMutableAttributedString(string: "\(author)\n", attributes: base)
        result.append(link(email, url: "mailto:\(email)", base: base))
        result.append(NSAttributedString(string: "\n", attributes: base))
        result.append(link("github.com/darknos/scrapbench", url: repository, base: base))
        return result
    }

    private static func link(_ title: String, url: String, base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attributes = base
        attributes[.link] = URL(string: url)!
        return NSAttributedString(string: title, attributes: attributes)
    }
}
