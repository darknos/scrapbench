import Foundation

/// The Automator workflow bundle that offers a script transformer as a
/// macOS Service. Two property lists, `Contents/Info.plist` and
/// `Contents/document.wflow`, shaped like the ones Automator writes for a
/// "replace selected text" service with one Run Shell Script action.
public struct ServiceWorkflow {
    public static let scriptIDKey = "ScrapbenchScriptID"
    public static let scriptPathKey = "ScrapbenchScriptPath"
    public static let bundleExtension = "workflow"
    static let titlePrefix = "Scrapbench: "
    static let bundlePrefix = "Scrapbench - "

    public let script: ScriptTransformer

    public init(script: ScriptTransformer) {
        self.script = script
    }

    public var title: String { Self.titlePrefix + script.name }

    /// Finder shows `:` in a file name as `/`, so both become `-`.
    public var bundleName: String {
        let safe = script.name.map { $0 == "/" || $0 == ":" ? "-" : String($0) }.joined()
        return Self.bundlePrefix + safe + "." + Self.bundleExtension
    }

    public var command: String {
        """
        export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        export LANG=en_US.UTF-8
        exec \(Self.shellQuoted(script.url.path))
        """
    }

    public static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public var infoPlist: [String: Any] {
        [
            "NSServices": [[
                "NSBackgroundColorName": "background",
                "NSIconName": "NSActionTemplate",
                "NSMenuItem": ["default": title],
                "NSMessage": "runWorkflowAsService",
                "NSReturnTypes": ["public.utf8-plain-text"],
                "NSSendTypes": ["public.utf8-plain-text"],
            ]],
            Self.scriptIDKey: script.id,
            Self.scriptPathKey: script.url.path,
        ]
    }

    public var document: [String: Any] {
        let action: [String: Any] = [
            "AMAccepts": ["Container": "List", "Optional": true, "Types": ["com.apple.cocoa.string"]],
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": [
                "COMMAND_STRING": [:], "CheckedForUserDefaultShell": [:], "inputMethod": [:], "shell": [:], "source": [:],
            ],
            "AMProvides": ["Container": "List", "Types": ["com.apple.cocoa.string"]],
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": [
                "COMMAND_STRING": command,
                "CheckedForUserDefaultShell": true,
                "inputMethod": 0,
                "shell": "/bin/sh",
                "source": "",
            ],
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": false,
            "CanShowWhenRun": true,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": UUID().uuidString,
            "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
            "OutputUUID": UUID().uuidString,
            "UUID": UUID().uuidString,
            "UnlocalizedApplications": ["Automator"],
            "arguments": [
                "0": argument("inputMethod", default: 0, uuid: "0"),
                "1": argument("CheckedForUserDefaultShell", default: false, uuid: "1"),
                "2": argument("source", default: "", uuid: "2"),
                "3": argument("COMMAND_STRING", default: "", uuid: "3"),
                "4": argument("shell", default: "/bin/sh", uuid: "4"),
            ],
            "isViewVisible": 1,
            "location": "309.000000:253.000000",
            "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
        ]
        return [
            "AMApplicationBuild": "534",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [["action": action, "isViewVisible": 1]],
            "connectors": [:],
            "workflowMetaData": [
                "applicationBundleIDsByPath": [:],
                "applicationPaths": [],
                "inputTypeIdentifier": "com.apple.Automator.text",
                "outputTypeIdentifier": "com.apple.Automator.text",
                "presentationMode": 11,
                "processesInput": false,
                "serviceInputTypeIdentifier": "com.apple.Automator.text",
                "serviceOutputTypeIdentifier": "com.apple.Automator.text",
                "serviceProcessesInput": false,
                "systemImageName": "NSActionTemplate",
                "useAutomaticInputType": true,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
            ],
        ]
    }

    private func argument(_ name: String, default value: Any, uuid: String) -> [String: Any] {
        ["default value": value, "name": name, "required": "0", "type": "0", "uuid": uuid]
    }
}
