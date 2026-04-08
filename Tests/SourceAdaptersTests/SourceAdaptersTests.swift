import AgentCore
import Foundation
import SourceAdapters
import XCTest

final class SourceAdaptersTests: XCTestCase {
    private var fixtureRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    private var fixtureEnvironment: AgentEnvironment {
        AgentEnvironment(
            homeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("agent-island-source-adapter-tests-home", isDirectory: true),
            workingDirectory: fixtureRoot.deletingLastPathComponent(),
            fixtureDirectory: fixtureRoot
        )
    }

    func testClaudeFixtureParsesQuestionPayload() async throws {
        let adapter = ClaudeSourceAdapter(fixtureRoot: fixtureRoot)
        let sessions = try await adapter.discoverSessions(in: fixtureEnvironment)
        let session = try XCTUnwrap(sessions.first)
        let events = try await adapter.loadEvents(for: session, in: fixtureEnvironment)

        XCTAssertEqual(events.last?.status, .waitingForInput)
        XCTAssertEqual(events.last?.questionPayload?.options.count, 2)
    }

    func testCodexFixtureParsesApprovalAndSubagentMetadata() async throws {
        let adapter = CodexSourceAdapter(fixtureRoot: fixtureRoot)
        let sessions = try await adapter.discoverSessions(in: fixtureEnvironment)
        let session = try XCTUnwrap(sessions.first)
        let events = try await adapter.loadEvents(for: session, in: fixtureEnvironment)

        XCTAssertEqual(events.last?.status, .waitingForApproval)
        XCTAssertEqual(events.last?.approvalPayload?.toolName, "apply_patch")
        XCTAssertEqual(events.last?.agentNickname, "Goodall")
        XCTAssertEqual(events.last?.subagentParentThreadId, "thread-main")
    }

    func testFactoryIncludesPlaceholderSources() {
        let adapters = AgentSourceAdapterFactory.live(fixtureRoot: fixtureRoot)
        XCTAssertTrue(adapters.contains { $0.source == .openclaw })
        XCTAssertTrue(adapters.contains { $0.source == .droid })
        XCTAssertTrue(adapters.contains { $0.source == .qoder })
        XCTAssertTrue(adapters.contains { $0.source == .codebuddy })
    }

    func testClaudeAdapterCanReadLegacyPrettyPrintedBridgeCaptures() async throws {
        let tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let captureDirectory = tempHome
            .appendingPathComponent(".agent-island/events/claude", isDirectory: true)
        try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: true)

        let capture = AgentBridgeCapture(
            source: .claude,
            sessionId: "legacy-session",
            hookName: "SessionStart",
            cwd: "/tmp/legacy-session",
            title: "Legacy bridge capture",
            message: "Hooks were modified by another tool.",
            status: .waitingForInput,
            timestamp: Date(timeIntervalSince1970: 1_750_000_000)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let fileURL = captureDirectory.appendingPathComponent("2026-04-05.jsonl")
        try encoder.encode(capture).write(to: fileURL, options: .atomic)

        let environment = AgentEnvironment(
            homeDirectory: tempHome,
            workingDirectory: fixtureRoot.deletingLastPathComponent(),
            fixtureDirectory: fixtureRoot
        )
        let adapter = ClaudeSourceAdapter(fixtureRoot: fixtureRoot, useFixturesAsFallback: false)
        let sessions = try await adapter.discoverSessions(in: environment)
        let session = try XCTUnwrap(sessions.first)
        let events = try await adapter.loadEvents(for: session, in: environment)

        XCTAssertEqual(session.sessionId, "legacy-session")
        XCTAssertEqual(events.last?.status, .waitingForInput)
        XCTAssertEqual(events.last?.lastAssistantMessage, "Hooks were modified by another tool.")
    }
}
