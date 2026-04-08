// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgentIsland",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "AgentCore", targets: ["AgentCore"]),
        .library(name: "SourceAdapters", targets: ["SourceAdapters"]),
        .library(name: "TerminalAdapters", targets: ["TerminalAdapters"]),
        .library(name: "IDEBridge", targets: ["IDEBridge"]),
        .library(name: "SoundKit", targets: ["SoundKit"]),
        .library(name: "Localization", targets: ["Localization"]),
        .library(name: "UpdateKit", targets: ["UpdateKit"]),
        .library(name: "Telemetry", targets: ["Telemetry"]),
        .library(name: "ClaudeIslandRuntime", targets: ["ClaudeIslandRuntime"]),
        .library(name: "AgentIslandUI", targets: ["AgentIslandUI"]),
        .executable(name: "AgentIslandApp", targets: ["AgentIslandApp"]),
        .executable(name: "agent-island-bridge", targets: ["AgentIslandBridge"]),
    ],
    targets: [
        .target(
            name: "AgentCore",
            path: "Modules/AgentCore"
        ),
        .target(
            name: "SourceAdapters",
            dependencies: ["AgentCore"],
            path: "Modules/SourceAdapters"
        ),
        .target(
            name: "TerminalAdapters",
            dependencies: ["AgentCore"],
            path: "Modules/TerminalAdapters"
        ),
        .target(
            name: "IDEBridge",
            dependencies: ["AgentCore", "TerminalAdapters", "SourceAdapters"],
            path: "Modules/IDEBridge"
        ),
        .target(
            name: "SoundKit",
            path: "Modules/SoundKit"
        ),
        .target(
            name: "Localization",
            path: "Modules/Localization"
        ),
        .target(
            name: "UpdateKit",
            path: "Modules/UpdateKit"
        ),
        .target(
            name: "Telemetry",
            path: "Modules/Telemetry"
        ),
        .target(
            name: "ClaudeIslandRuntime",
            path: "Vendor/ClaudeIslandRuntime",
            exclude: ["README.md"]
        ),
        .target(
            name: "AgentIslandUI",
            dependencies: [
                "AgentCore",
                "SourceAdapters",
                "TerminalAdapters",
                "IDEBridge",
                "SoundKit",
                "Localization",
                "UpdateKit",
                "Telemetry",
                "ClaudeIslandRuntime",
            ],
            path: "App/Sources"
        ),
        .executableTarget(
            name: "AgentIslandApp",
            dependencies: ["AgentIslandUI", "ClaudeIslandRuntime"],
            path: "App/Entry"
        ),
        .executableTarget(
            name: "AgentIslandBridge",
            dependencies: [
                "AgentCore",
                "SourceAdapters",
                "IDEBridge",
                "TerminalAdapters",
            ],
            path: "Bridge"
        ),
        .testTarget(
            name: "AgentCoreTests",
            dependencies: ["AgentCore"],
            path: "Tests/AgentCoreTests"
        ),
        .testTarget(
            name: "SourceAdaptersTests",
            dependencies: ["AgentCore", "SourceAdapters"],
            path: "Tests/SourceAdaptersTests"
        ),
        .testTarget(
            name: "TerminalAdaptersTests",
            dependencies: ["AgentCore", "TerminalAdapters"],
            path: "Tests/TerminalAdaptersTests"
        ),
        .testTarget(
            name: "SoundKitTests",
            dependencies: ["SoundKit"],
            path: "Tests/SoundKitTests"
        ),
        .testTarget(
            name: "AgentIslandAppTests",
            dependencies: ["AgentCore", "AgentIslandUI"],
            path: "Tests/AgentIslandAppTests"
        ),
    ]
)
