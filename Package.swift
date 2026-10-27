// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Scrapbench",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/nicklockwood/Expression", from: "0.13.0"),
    ],
    targets: [
        .target(
            name: "ScrapbenchCore",
            dependencies: [.product(name: "Expression", package: "Expression")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "ScrapbenchApp",
            dependencies: [
                "ScrapbenchCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ScrapbenchCoreTests",
            dependencies: ["ScrapbenchCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
