// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DailyNotes",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "DailyNotesCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "DailyNotesApp",
            dependencies: [
                "DailyNotesCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DailyNotesCoreTests",
            dependencies: ["DailyNotesCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
