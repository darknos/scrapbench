import AppKit

let arguments = CommandLine.arguments
if arguments.count > 1, arguments[1] == "--transform" || arguments[1] == "--set-key" {
    guard arguments.count == 3 else {
        FileHandle.standardError.write(Data("usage: Scrapbench --transform <id> | --set-key <anthropic|other>\n".utf8))
        exit(1)
    }
    exit(arguments[1] == "--transform" ? HeadlessTransform.run(id: arguments[2]) : HeadlessTransform.setKey(account: arguments[2]))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
