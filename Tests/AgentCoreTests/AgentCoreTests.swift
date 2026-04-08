import AgentCore
import XCTest

final class AgentCoreTests: XCTestCase {
    func testSessionStoreAppliesLatestEvent() async {
        let now = Date()
        let events = [
            AgentEvent(
                source: .codex,
                sessionId: "codex-panel",
                title: "Implement panel shortcuts",
                status: .thinking,
                timestamp: now.addingTimeInterval(-30)
            ),
            AgentEvent(
                source: .codex,
                sessionId: "codex-panel",
                title: "Implement panel shortcuts",
                status: .waitingForApproval,
                approvalPayload: AgentApprovalPayload(toolName: "apply_patch", summary: "Patch files", choices: ["Allow"]),
                timestamp: now
            ),
        ]

        let store = SessionIndexStore()
        let snapshot = await store.apply(events)

        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(snapshot.first?.status, .waitingForApproval)
        XCTAssertEqual(snapshot.first?.approvalPayload?.toolName, "apply_patch")
    }

    func testSubagentGroupingUsesParentThreadIdentifier() {
        let now = Date()
        let sessions = [
            AgentSession(source: .codex, sessionId: "a", title: "Main", status: .thinking, lastUpdated: now),
            {
                var session = AgentSession(source: .codex, sessionId: "b", title: "Subagent", status: .runningTool, lastUpdated: now)
                session.subagentParentThreadId = "thread-main"
                return session
            }(),
            {
                var session = AgentSession(source: .claude, sessionId: "c", title: "Subagent 2", status: .waitingForInput, lastUpdated: now)
                session.subagentParentThreadId = "thread-main"
                return session
            }(),
        ]

        let groups = AgentSessionGrouper.group(sessions)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.sessions.count, 2)
    }

    func testQuestionPayloadRoundTrip() throws {
        let payload = AgentQuestionPayload(
            prompt: "Restore hooks?",
            allowsMultipleSelection: false,
            options: [AgentQuestionOption(id: "restore", title: "Restore")]
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AgentQuestionPayload.self, from: data)
        XCTAssertEqual(decoded.prompt, payload.prompt)
        XCTAssertEqual(decoded.options.first?.id, "restore")
    }

    func testSupportLevelsSeparateFirstClassAndExperimentalSources() {
        XCTAssertEqual(AgentSource.claude.supportLevel, .supported)
        XCTAssertEqual(AgentSource.codex.supportLevel, .supported)
        XCTAssertEqual(AgentSource.gemini.supportLevel, .supported)
        XCTAssertEqual(AgentSource.openclaw.supportLevel, .supported)
        XCTAssertEqual(AgentSource.cursor.supportLevel, .experimental)
        XCTAssertEqual(AgentSource.copilot.supportLevel, .experimental)
        XCTAssertEqual(AgentSource.firstClassProductSources, [.claude, .codex, .gemini, .openclaw])
    }
}
