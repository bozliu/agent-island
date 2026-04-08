import AgentCore
import Foundation
import TerminalAdapters
import XCTest

private struct MockLocator: ApplicationLocator {
    let installedBundleIdentifiers: Set<String>

    func isInstalled(bundleIdentifier: String) -> Bool {
        installedBundleIdentifiers.contains(bundleIdentifier)
    }
}

private final class MockRunner: AppleScriptRunning, @unchecked Sendable {
    private(set) var scripts: [String] = []

    func run(_ script: String) throws {
        scripts.append(script)
    }
}

final class TerminalAdaptersTests: XCTestCase {
    func testITermCapabilityReflectsInstallationState() {
        let adapter = ITermAdapter(locator: MockLocator(installedBundleIdentifiers: ["com.googlecode.iterm2"]), runner: MockRunner())
        XCTAssertTrue(adapter.capability().isInstalled)
        XCTAssertTrue(adapter.capability().supportsPreciseJump)
    }

    func testJumpScriptIncludesSessionIdentifier() throws {
        let runner = MockRunner()
        let adapter = ITermAdapter(locator: MockLocator(installedBundleIdentifiers: ["com.googlecode.iterm2"]), runner: runner)
        try adapter.jump(to: TerminalSessionDescriptor(kind: .iTerm2, identifier: "iterm-codex-42", displayName: "Codex"))
        XCTAssertTrue(runner.scripts.joined(separator: "\n").contains("iterm-codex-42"))
    }

    func testRegistryReportsCapabilities() {
        let registry = TerminalAdapterRegistry(adapters: [
            ITermAdapter(locator: MockLocator(installedBundleIdentifiers: []), runner: MockRunner()),
            AppleTerminalAdapter(locator: MockLocator(installedBundleIdentifiers: ["com.apple.Terminal"]), runner: MockRunner()),
        ])

        XCTAssertEqual(registry.capabilityReport().count, 2)
        XCTAssertTrue(registry.capabilityReport().contains { $0.kind == .terminal && $0.isInstalled })
    }

    func testTerminalKindInferenceCoversShippedJumpTargets() {
        XCTAssertEqual(TerminalKind.inferred(from: "iterm-codex-42"), .iterm)
        XCTAssertEqual(TerminalKind.inferred(from: "terminal-claude-3"), .terminal)
        XCTAssertEqual(TerminalKind.inferred(from: "warp-gemini-7"), .warp)
        XCTAssertEqual(TerminalKind.inferred(from: "cursor-ide-1"), .cursor)
        XCTAssertEqual(TerminalKind.inferred(from: "vscode-term-1"), .vscode)
        XCTAssertEqual(TerminalKind.inferred(from: "tmux:session:1.2"), .tmux)
    }
}
