import AppKit
import Foundation

public struct TerminalSessionDescriptor: Sendable {
    public let kind: TerminalKind
    public let identifier: String
    public let displayName: String

    public init(kind: TerminalKind, identifier: String, displayName: String) {
        self.kind = kind
        self.identifier = identifier
        self.displayName = displayName
    }
}

public enum TerminalKind: String, Codable, Sendable, CaseIterable {
    case iterm = "iTerm2"
    case terminal = "Terminal.app"
    case warp = "Warp"
    case vscode = "VS Code"
    case cursor = "Cursor"
    case tmux = "tmux"
    case unknown = "Unknown"
    
    // Alias for tests
    public static var iTerm2: TerminalKind { .iterm }

    public static func inferred(from identifier: String) -> TerminalKind {
        let lowered = identifier.lowercased()
        if lowered.hasPrefix("iterm") {
            return .iterm
        }
        if lowered.hasPrefix("terminal") {
            return .terminal
        }
        if lowered.hasPrefix("warp") {
            return .warp
        }
        if lowered.hasPrefix("cursor") {
            return .cursor
        }
        if lowered.hasPrefix("vscode") || lowered.hasPrefix("code") {
            return .vscode
        }
        if lowered.hasPrefix("tmux") {
            return .tmux
        }
        return .unknown
    }
}

public protocol ApplicationLocator: Sendable {
    func isInstalled(bundleIdentifier: String) -> Bool
}

public protocol AppleScriptRunning: Sendable {
    func run(_ script: String) throws
}

public struct DefaultApplicationLocator: ApplicationLocator {
    public init() {}
    public func isInstalled(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}

public final class DefaultAppleScriptRunner: AppleScriptRunning, @unchecked Sendable {
    public init() {}
    public func run(_ script: String) throws {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let err = error {
                throw NSError(domain: "AppleScriptError", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(err)"])
            }
        }
    }
}

public struct TerminalCapability: Codable, Sendable {
    public let kind: TerminalKind
    public let isInstalled: Bool
    public let supportsJumping: Bool
    public let supportsPreciseJump: Bool
    public let notes: String?

    public init(kind: TerminalKind, isInstalled: Bool, supportsJumping: Bool, supportsPreciseJump: Bool = false, notes: String? = nil) {
        self.kind = kind
        self.isInstalled = isInstalled
        self.supportsJumping = supportsJumping
        self.supportsPreciseJump = supportsPreciseJump
        self.notes = notes
    }
}

public protocol TerminalAdapter: Sendable {
    var kind: TerminalKind { get }
    func capability() -> TerminalCapability
    func jump(to session: TerminalSessionDescriptor) throws
}

public final class TerminalAdapterRegistry: Sendable {
    public let adapters: [any TerminalAdapter]

    public init(adapters: [any TerminalAdapter]) {
        self.adapters = adapters
    }

    public static func live() -> TerminalAdapterRegistry {
        TerminalAdapterRegistry(adapters: [
            ITermAdapter(),
            AppleTerminalAdapter(),
            WarpAdapter(),
            VSCodeAdapter(),
            CursorTerminalAdapter(),
            TmuxAdapter(),
        ])
    }

    public func capabilityReport() -> [TerminalCapability] {
        adapters.map { $0.capability() }
    }

    public func adapter(for kind: TerminalKind) -> (any TerminalAdapter)? {
        adapters.first { $0.kind == kind }
    }
}

public struct ITermAdapter: TerminalAdapter {
    public let kind: TerminalKind = .iterm
    private let locator: any ApplicationLocator
    private let runner: any AppleScriptRunning

    public init(locator: any ApplicationLocator = DefaultApplicationLocator(), runner: any AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.locator = locator
        self.runner = runner
    }

    public func capability() -> TerminalCapability {
        let isInstalled = locator.isInstalled(bundleIdentifier: "com.googlecode.iterm2")
        return TerminalCapability(kind: kind, isInstalled: isInstalled, supportsJumping: true, supportsPreciseJump: true, notes: "Supports precise session ID jumping via AppleScript.")
    }

    public func jump(to session: TerminalSessionDescriptor) throws {
        let script = """
        tell application "iTerm"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if id of s is "\(session.identifier)" then
                            select s
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        try runner.run(script)
    }
}

public struct AppleTerminalAdapter: TerminalAdapter {
    public let kind: TerminalKind = .terminal
    private let locator: any ApplicationLocator
    private let runner: any AppleScriptRunning

    public init(locator: any ApplicationLocator = DefaultApplicationLocator(), runner: any AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.locator = locator
        self.runner = runner
    }

    public func capability() -> TerminalCapability {
        return TerminalCapability(
            kind: kind,
            isInstalled: locator.isInstalled(bundleIdentifier: "com.apple.Terminal"),
            supportsJumping: true,
            notes: "Basic window focus support."
        )
    }

    public func jump(to session: TerminalSessionDescriptor) throws {
        let script = """
        tell application "Terminal"
            activate
            set frontmost to true
        end tell
        """
        try runner.run(script)
    }
}

public struct WarpAdapter: TerminalAdapter {
    public let kind: TerminalKind = .warp
    private let locator: any ApplicationLocator
    private let runner: any AppleScriptRunning

    public init(locator: any ApplicationLocator = DefaultApplicationLocator(), runner: any AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.locator = locator
        self.runner = runner
    }

    public func capability() -> TerminalCapability {
        TerminalCapability(
            kind: kind,
            isInstalled: locator.isInstalled(bundleIdentifier: "dev.warp.Warp-Stable"),
            supportsJumping: true,
            notes: "Foregrounds Warp when a Warp-linked session needs attention."
        )
    }

    public func jump(to session: TerminalSessionDescriptor) throws {
        let script = """
        tell application "Warp"
            activate
        end tell
        """
        try runner.run(script)
    }
}

public struct VSCodeAdapter: TerminalAdapter {
    public let kind: TerminalKind = .vscode
    private let locator: any ApplicationLocator
    private let runner: any AppleScriptRunning

    public init(locator: any ApplicationLocator = DefaultApplicationLocator(), runner: any AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.locator = locator
        self.runner = runner
    }

    public func capability() -> TerminalCapability {
        let installed = locator.isInstalled(bundleIdentifier: "com.microsoft.VSCode")
            || locator.isInstalled(bundleIdentifier: "com.microsoft.VSCodeInsiders")
        return TerminalCapability(
            kind: kind,
            isInstalled: installed,
            supportsJumping: true,
            notes: "Foregrounds VS Code when the IDE terminal bridge is the best available target."
        )
    }

    public func jump(to session: TerminalSessionDescriptor) throws {
        let script = """
        tell application "Visual Studio Code"
            activate
        end tell
        """
        try runner.run(script)
    }
}

public struct CursorTerminalAdapter: TerminalAdapter {
    public let kind: TerminalKind = .cursor
    private let runner: any AppleScriptRunning

    public init(runner: any AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.runner = runner
    }

    public func capability() -> TerminalCapability {
        TerminalCapability(
            kind: kind,
            isInstalled: FileManager.default.fileExists(atPath: "/Applications/Cursor.app")
                || FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Applications/Cursor.app"),
            supportsJumping: true,
            notes: "Foregrounds Cursor when a Cursor terminal bridge target is available."
        )
    }

    public func jump(to session: TerminalSessionDescriptor) throws {
        let script = """
        tell application "Cursor"
            activate
        end tell
        """
        try runner.run(script)
    }
}

public struct TmuxAdapter: TerminalAdapter {
    public let kind: TerminalKind = .tmux

    public init() {}

    public func capability() -> TerminalCapability {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "tmux"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return TerminalCapability(
                kind: kind,
                isInstalled: task.terminationStatus == 0,
                supportsJumping: true,
                supportsPreciseJump: true,
                notes: "Switches tmux client, pane, or window targets when tmux metadata is available."
            )
        } catch {
            return TerminalCapability(
                kind: kind,
                isInstalled: false,
                supportsJumping: false,
                notes: "tmux executable was not found."
            )
        }
    }

    public func jump(to session: TerminalSessionDescriptor) throws {
        let command = "tmux switch-client -t \(shellEscape(session.identifier)) || tmux select-pane -t \(shellEscape(session.identifier)) || tmux select-window -t \(shellEscape(session.identifier))"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        try process.run()
    }

    private func shellEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
