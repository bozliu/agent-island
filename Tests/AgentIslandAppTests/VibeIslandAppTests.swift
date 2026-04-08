import AgentCore
import ClaudeIslandRuntime
import AgentIslandUI
import XCTest

@MainActor
final class AgentIslandAppTests: XCTestCase {
    func testPreviewModelHasSessionsAndSelection() {
        let model = AppModel.preview()
        XCTAssertFalse(model.sessions.isEmpty)
        XCTAssertNotNil(model.selectedSession)
        XCTAssertTrue(model.menuBarTitle.contains("Agent Island"))
    }

    func testVisibleTasksCanHideCompletedEntries() {
        let model = AppModel.preview()
        guard let session = model.sessions.first else {
            return XCTFail("Expected preview sessions.")
        }

        model.showCompletedTasks = false
        XCTAssertLessThanOrEqual(model.visibleTasks(for: session).count, session.tasks.count)
    }

    func testCollapseIslandCanReturnToCompactStateEvenWithAttention() {
        let model = AppModel.preview()

        XCTAssertFalse(model.attentionSessions.isEmpty)
        model.expandIsland()
        model.collapseIsland()

        XCTAssertFalse(model.islandExpanded)
    }

    func testCodexDirectSubmissionUsesResumeCommand() {
        let model = AppModel.preview()
        let session = AgentSession(
            source: .codex,
            sessionId: "abc-123",
            title: "Codex Session",
            status: .waitingForInput,
            lastUpdated: .now
        ).with {
            $0.workingDirectory = "/tmp/project"
            $0.resumeCommand = "cd '/tmp/project' && codex resume 'abc-123'"
        }

        let plan = model.directSubmissionPlan(for: session, response: "Ship it")
        guard case .terminalCommand(let command)? = plan else {
            return XCTFail("Expected terminal command plan for Codex.")
        }

        XCTAssertTrue(command.contains("codex resume"))
        XCTAssertTrue(command.contains("Ship it"))
    }

    func testGeminiDirectSubmissionUsesResumeAndPromptFlags() {
        let model = AppModel.preview()
        let session = AgentSession(
            source: .gemini,
            sessionId: "gem-123",
            title: "Gemini Session",
            status: .waitingForInput,
            lastUpdated: .now
        )

        let plan = model.directSubmissionPlan(for: session, response: "Use option A")
        guard case .detachedCLI(let executable, let arguments, _)? = plan else {
            return XCTFail("Expected detached CLI plan for Gemini.")
        }

        XCTAssertEqual(executable, "gemini")
        XCTAssertEqual(arguments, ["--resume", "gem-123", "--prompt", "Use option A"])
    }

    func testClaudeDirectSubmissionUsesNode24ResumeAndPrintMode() {
        let model = AppModel.preview()
        let session = AgentSession(
            source: .claude,
            sessionId: "claude-123",
            title: "Claude Session",
            status: .waitingForApproval,
            lastUpdated: .now
        )

        let plan = model.directSubmissionPlan(for: session, response: "Allow once")
        guard case .detachedCLI(let executable, let arguments, _)? = plan else {
            return XCTFail("Expected detached CLI plan for Claude.")
        }

        XCTAssertEqual(executable, "/opt/homebrew/opt/node@24/bin/node")
        XCTAssertEqual(arguments, ["/opt/homebrew/bin/claude", "--resume", "claude-123", "--print", "Allow once"])
    }

    func testOpenClawFallsBackToResumeCommandWhenAvailable() {
        let model = AppModel.preview()
        let session = AgentSession(
            source: .openclaw,
            sessionId: "opencode-123",
            title: "OpenClaw Session",
            status: .waitingForInput,
            lastUpdated: .now
        ).with {
            $0.resumeCommand = "openclaw agent --session-id opencode-123 --message"
        }

        let plan = model.directSubmissionPlan(for: session, response: "Answer now")
        guard case .terminalCommand(let command)? = plan else {
            return XCTFail("Expected terminal command plan for OpenClaw.")
        }

        XCTAssertTrue(command.contains("openclaw agent --session-id"))
        XCTAssertTrue(command.contains("Answer now"))
    }

    func testSubmittedApprovalLeavesApproveQueue() {
        let model = AppModel.preview()
        model.setDashboardMode(.approve)

        XCTAssertEqual(model.sessions(for: .approve).count, 1)
        model.markSelectedSessionAsSubmitted(response: "Allow once")

        XCTAssertEqual(model.sessions(for: .approve).count, 0)
    }

    func testIslandAnchorMetricsAnchorContentToNotchBottom() {
        let metrics = IslandAnchorMetrics(
            screenRect: CGRect(x: 0, y: 0, width: 1800, height: 1169),
            visibleFrame: CGRect(x: 0, y: 88, width: 1800, height: 1042),
            topUnsafeInset: 38,
            notchBottomY: 1131,
            shellHeight: 758
        )

        let compact = metrics.contentRect(for: CGSize(width: 224, height: 38))
        let expanded = metrics.contentRect(for: CGSize(width: 920, height: 560))

        XCTAssertEqual(compact.maxY, 720)
        XCTAssertEqual(expanded.maxY, 720)
        XCTAssertEqual(compact.minX, 788)
        XCTAssertEqual(expanded.minX, 440)
    }

    func testScreenMetricsPreferAuxiliaryInsetForNotchAlignment() {
        let topInset = AgentIslandScreenMetrics.topUnsafeInset(
            safeAreaTop: 74,
            visibleTopInset: 39,
            auxiliaryTopInset: 38
        )
        let notchHeight = AgentIslandScreenMetrics.notchHeight(
            safeAreaTop: 74,
            auxiliaryTopInset: 38
        )

        XCTAssertEqual(topInset, 38)
        XCTAssertEqual(notchHeight, 38)
    }

    func testScreenMetricsFallBackToVisibleInsetWithoutAuxiliaryAreas() {
        let topInset = AgentIslandScreenMetrics.topUnsafeInset(
            safeAreaTop: 74,
            visibleTopInset: 39,
            auxiliaryTopInset: nil
        )

        XCTAssertEqual(topInset, 39)
    }
}

private extension AgentSession {
    func with(_ mutate: (inout AgentSession) -> Void) -> AgentSession {
        var copy = self
        mutate(&copy)
        return copy
    }
}
