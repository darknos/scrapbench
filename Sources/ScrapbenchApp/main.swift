import AppKit

let arguments = CommandLine.arguments
if arguments.count == 3, arguments[1] == "--transform" {
    exit(HeadlessTransform.run(id: arguments[2]))
}
if arguments.count == 3, arguments[1] == "--set-key" {
    exit(HeadlessTransform.setKey(account: arguments[2]))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
