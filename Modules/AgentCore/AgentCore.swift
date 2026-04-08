import Foundation

public enum AgentSource: String, Codable, CaseIterable, Sendable, Hashable {
    case claude
    case codex
    case gemini
    case openclaw
    case cursor
    case copilot
    case droid
    case qoder
    case codebuddy
}

public enum AgentSupportLevel: String, Codable, CaseIterable, Sendable, Hashable {
    case supported
    case experimental
    case hidden
}

public extension AgentSource {
    var supportLevel: AgentSupportLevel {
        switch self {
        case .claude, .codex, .gemini, .openclaw:
            return .supported
        case .cursor, .copilot:
            return .experimental
        case .droid, .qoder, .codebuddy:
            return .hidden
        }
    }

    var isFirstClassSupported: Bool {
        supportLevel == .supported
    }

    var isProductVisible: Bool {
        supportLevel != .hidden
    }

    var displayName: String {
        switch self {
        case .claude:
            return "Claude Code"
        case .codex:
            return "Codex CLI"
        case .gemini:
            return "Gemini CLI"
        case .openclaw:
            return "OpenCode"
        case .cursor:
            return "Cursor"
        case .copilot:
            return "GitHub Copilot CLI"
        case .droid:
            return "Factory Droid"
        case .qoder:
            return "Qoder"
        case .codebuddy:
            return "CodeBuddy"
        }
    }

    static var firstClassProductSources: [AgentSource] {
        allCases.filter(\.isFirstClassSupported)
    }

    static var visibleProductSources: [AgentSource] {
        allCases.filter(\.isProductVisible)
    }
}

public enum AgentStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case idle
    case thinking
    case runningTool
    case waitingForApproval
    case waitingForInput
    case complete
    case compacting
    case error
    case interrupted

    public var needsAttention: Bool {
        switch self {
        case .waitingForApproval, .waitingForInput, .error:
            return true
        default:
            return false
        }
    }
}

public enum AgentTimelineEntryKind: String, Codable, CaseIterable, Sendable, Hashable {
    case user
    case assistant
    case tool
    case system
}

public struct AgentTimelineEntry: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let kind: AgentTimelineEntryKind
    public let title: String
    public let detail: String?
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        kind: AgentTimelineEntryKind,
        title: String,
        detail: String? = nil,
        timestamp: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.timestamp = timestamp
    }
}

public struct AgentQuestionOption: Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let detail: String?

    public init(id: String, title: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public struct AgentQuestionPayload: Codable, Sendable, Hashable {
    public let prompt: String
    public let allowsMultipleSelection: Bool
    public let options: [AgentQuestionOption]

    public init(prompt: String, allowsMultipleSelection: Bool, options: [AgentQuestionOption]) {
        self.prompt = prompt
        self.allowsMultipleSelection = allowsMultipleSelection
        self.options = options
    }
}

public struct AgentApprovalFileChange: Codable, Sendable, Hashable {
    public let path: String
    public let summary: String

    public init(path: String, summary: String) {
        self.path = path
        self.summary = summary
    }
}

public struct AgentApprovalPayload: Codable, Sendable, Hashable {
    public let toolName: String
    public let summary: String
    public let choices: [String]
    public let fileChanges: [AgentApprovalFileChange]

    public init(toolName: String, summary: String, choices: [String], fileChanges: [AgentApprovalFileChange] = []) {
        self.toolName = toolName
        self.summary = summary
        self.choices = choices
        self.fileChanges = fileChanges
    }
}

public struct AgentUsageSnapshot: Codable, Sendable, Hashable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?

    public init(promptTokens: Int? = nil, completionTokens: Int? = nil, totalTokens: Int? = nil) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

public struct AgentTaskSnapshot: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let isComplete: Bool

    public init(id: String, title: String, isComplete: Bool) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
    }
}

public struct AgentBridgeCapture: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let source: AgentSource
    public let sessionId: String?
    public let hookName: String?
    public let cwd: String?
    public let title: String?
    public let message: String?
    public let toolName: String?
    public let terminalSessionId: String?
    public let status: AgentStatus
    public let rawInput: String?
    public let metadata: [String: String]
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        source: AgentSource,
        sessionId: String? = nil,
        hookName: String? = nil,
        cwd: String? = nil,
        title: String? = nil,
        message: String? = nil,
        toolName: String? = nil,
        terminalSessionId: String? = nil,
        status: AgentStatus,
        rawInput: String? = nil,
        metadata: [String: String] = [:],
        timestamp: Date
    ) {
        self.id = id
        self.source = source
        self.sessionId = sessionId
        self.hookName = hookName
        self.cwd = cwd
        self.title = title
        self.message = message
        self.toolName = toolName
        self.terminalSessionId = terminalSessionId
        self.status = status
        self.rawInput = rawInput
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

public struct AgentEvent: Codable, Sendable, Hashable, Identifiable {
    public let eventId: String
    public let source: AgentSource
    public let sessionId: String
    public let threadId: String?
    public let turnId: String?
    public let terminalSessionId: String?
    public let title: String
    public let status: AgentStatus
    public let lastAssistantMessage: String?
    public let questionPayload: AgentQuestionPayload?
    public let approvalPayload: AgentApprovalPayload?
    public let usage: AgentUsageSnapshot?
    public let subagentParentThreadId: String?
    public let agentNickname: String?
    public let agentRole: String?
    public let tasks: [AgentTaskSnapshot]
    public let timeline: [AgentTimelineEntry]
    public let workingDirectory: String?
    public let originPath: String?
    public let resumeCommand: String?
    public let timestamp: Date

    public var id: String { eventId }

    public init(
        eventId: String = UUID().uuidString,
        source: AgentSource,
        sessionId: String,
        threadId: String? = nil,
        turnId: String? = nil,
        terminalSessionId: String? = nil,
        title: String,
        status: AgentStatus,
        lastAssistantMessage: String? = nil,
        questionPayload: AgentQuestionPayload? = nil,
        approvalPayload: AgentApprovalPayload? = nil,
        usage: AgentUsageSnapshot? = nil,
        subagentParentThreadId: String? = nil,
        agentNickname: String? = nil,
        agentRole: String? = nil,
        tasks: [AgentTaskSnapshot] = [],
        timeline: [AgentTimelineEntry] = [],
        workingDirectory: String? = nil,
        originPath: String? = nil,
        resumeCommand: String? = nil,
        timestamp: Date
    ) {
        self.eventId = eventId
        self.source = source
        self.sessionId = sessionId
        self.threadId = threadId
        self.turnId = turnId
        self.terminalSessionId = terminalSessionId
        self.title = title
        self.status = status
        self.lastAssistantMessage = lastAssistantMessage
        self.questionPayload = questionPayload
        self.approvalPayload = approvalPayload
        self.usage = usage
        self.subagentParentThreadId = subagentParentThreadId
        self.agentNickname = agentNickname
        self.agentRole = agentRole
        self.tasks = tasks
        self.timeline = timeline
        self.workingDirectory = workingDirectory
        self.originPath = originPath
        self.resumeCommand = resumeCommand
        self.timestamp = timestamp
    }
}

public struct DiscoveredSession: Codable, Sendable, Hashable, Identifiable {
    public let source: AgentSource
    public let sessionId: String
    public let title: String
    public let threadId: String?
    public let terminalSessionId: String?
    public let fileURL: URL?

    public var id: String { "\(source.rawValue):\(sessionId)" }

    public init(
        source: AgentSource,
        sessionId: String,
        title: String,
        threadId: String? = nil,
        terminalSessionId: String? = nil,
        fileURL: URL? = nil
    ) {
        self.source = source
        self.sessionId = sessionId
        self.title = title
        self.threadId = threadId
        self.terminalSessionId = terminalSessionId
        self.fileURL = fileURL
    }
}

public enum HookInstallationStatus: String, Codable, Sendable, Hashable {
    case installed
    case repaired
    case manual
    case unavailable
}

public struct HookInstallationResult: Codable, Sendable, Hashable {
    public let source: AgentSource
    public let status: HookInstallationStatus
    public let message: String
    public let touchedPaths: [String]

    public init(source: AgentSource, status: HookInstallationStatus, message: String, touchedPaths: [String]) {
        self.source = source
        self.status = status
        self.message = message
        self.touchedPaths = touchedPaths
    }
}

public struct AgentEnvironment: Codable, Sendable, Hashable {
    public let homeDirectory: URL
    public let workingDirectory: URL
    public let fixtureDirectory: URL

    public init(homeDirectory: URL, workingDirectory: URL, fixtureDirectory: URL) {
        self.homeDirectory = homeDirectory
        self.workingDirectory = workingDirectory
        self.fixtureDirectory = fixtureDirectory
    }

    public static func live(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> AgentEnvironment {
        AgentEnvironment(
            homeDirectory: homeDirectory,
            workingDirectory: workingDirectory,
            fixtureDirectory: workingDirectory.appendingPathComponent("Fixtures", isDirectory: true)
        )
    }
}

public struct AgentSession: Codable, Sendable, Hashable, Identifiable {
    public let source: AgentSource
    public let sessionId: String
    public var threadId: String?
    public var turnId: String?
    public var terminalSessionId: String?
    public var title: String
    public var status: AgentStatus
    public var lastAssistantMessage: String?
    public var questionPayload: AgentQuestionPayload?
    public var approvalPayload: AgentApprovalPayload?
    public var usage: AgentUsageSnapshot?
    public var subagentParentThreadId: String?
    public var agentNickname: String?
    public var agentRole: String?
    public var tasks: [AgentTaskSnapshot]
    public var timeline: [AgentTimelineEntry]
    public var workingDirectory: String?
    public var originPath: String?
    public var resumeCommand: String?
    public var lastUpdated: Date

    public var id: String { "\(source.rawValue):\(sessionId)" }
    public var isSubagent: Bool { subagentParentThreadId != nil }
    public var needsAttention: Bool { status.needsAttention }
    public var completedTaskCount: Int { tasks.filter(\.isComplete).count }

    public init(source: AgentSource, sessionId: String, title: String, status: AgentStatus, lastUpdated: Date) {
        self.source = source
        self.sessionId = sessionId
        self.title = title
        self.status = status
        self.lastUpdated = lastUpdated
        self.threadId = nil
        self.turnId = nil
        self.terminalSessionId = nil
        self.lastAssistantMessage = nil
        self.questionPayload = nil
        self.approvalPayload = nil
        self.usage = nil
        self.subagentParentThreadId = nil
        self.agentNickname = nil
        self.agentRole = nil
        self.tasks = []
        self.timeline = []
        self.workingDirectory = nil
        self.originPath = nil
        self.resumeCommand = nil
    }

    public mutating func apply(_ event: AgentEvent) {
        threadId = event.threadId ?? threadId
        turnId = event.turnId ?? turnId
        terminalSessionId = event.terminalSessionId ?? terminalSessionId
        title = event.title
        status = event.status
        lastAssistantMessage = event.lastAssistantMessage ?? lastAssistantMessage
        questionPayload = event.questionPayload
        approvalPayload = event.approvalPayload
        usage = event.usage ?? usage
        subagentParentThreadId = event.subagentParentThreadId ?? subagentParentThreadId
        agentNickname = event.agentNickname ?? agentNickname
        agentRole = event.agentRole ?? agentRole
        tasks = event.tasks.isEmpty ? tasks : event.tasks
        timeline = event.timeline.isEmpty ? timeline : event.timeline
        workingDirectory = event.workingDirectory ?? workingDirectory
        originPath = event.originPath ?? originPath
        resumeCommand = event.resumeCommand ?? resumeCommand
        lastUpdated = event.timestamp
    }
}

public struct AgentSessionGroup: Sendable, Hashable, Identifiable {
    public let parentThreadId: String
    public let sessions: [AgentSession]

    public var id: String { parentThreadId }
}

public enum AgentSessionGrouper {
    public static func group(_ sessions: [AgentSession]) -> [AgentSessionGroup] {
        let grouped = Dictionary(grouping: sessions.filter(\.isSubagent)) { session in
            session.subagentParentThreadId ?? session.threadId ?? session.sessionId
        }

        return grouped
            .map { AgentSessionGroup(parentThreadId: $0.key, sessions: $0.value.sorted { $0.lastUpdated > $1.lastUpdated }) }
            .sorted { $0.parentThreadId < $1.parentThreadId }
    }
}

public actor SessionIndexStore {
    private var sessions: [String: AgentSession] = [:]

    public init() {}

    @discardableResult
    public func apply(_ events: [AgentEvent]) -> [AgentSession] {
        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            let key = sessionKey(source: event.source, sessionId: event.sessionId)
            var session = sessions[key] ?? AgentSession(
                source: event.source,
                sessionId: event.sessionId,
                title: event.title,
                status: event.status,
                lastUpdated: event.timestamp
            )
            session.apply(event)
            sessions[key] = session
        }

        return snapshot()
    }

    @discardableResult
    public func replace(with events: [AgentEvent]) -> [AgentSession] {
        sessions = [:]
        return apply(events)
    }

    public func snapshot() -> [AgentSession] {
        sessions.values.sorted { lhs, rhs in
            if lhs.needsAttention != rhs.needsAttention {
                return lhs.needsAttention && !rhs.needsAttention
            }
            return lhs.lastUpdated > rhs.lastUpdated
        }
    }

    public func reset(with sessions: [AgentSession]) {
        self.sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    private func sessionKey(source: AgentSource, sessionId: String) -> String {
        "\(source.rawValue):\(sessionId)"
    }
}

public enum DemoFixtures {
    public static func defaultEvents(referenceDate: Date = .now) -> [AgentEvent] {
        [
            AgentEvent(
                source: .codex,
                sessionId: "codex-panel",
                threadId: "thread-panel",
                turnId: "turn-14",
                terminalSessionId: "iterm-codex-42",
                title: "Implement panel shortcuts",
                status: .waitingForApproval,
                lastAssistantMessage: "Prepared a patch for panel navigation and needs permission to apply it.",
                approvalPayload: AgentApprovalPayload(
                    toolName: "apply_patch",
                    summary: "Update the panel shortcut handler and add keyboard hints.",
                    choices: ["Allow once", "Always allow", "Deny"],
                    fileChanges: [
                        AgentApprovalFileChange(path: "App/Sources/SettingsView.swift", summary: "Add shortcut legend"),
                        AgentApprovalFileChange(path: "App/Sources/IslandDashboardView.swift", summary: "Wire arrow navigation"),
                    ]
                ),
                usage: AgentUsageSnapshot(promptTokens: 1_240_000, completionTokens: 518_000, totalTokens: 1_758_000),
                tasks: [
                    AgentTaskSnapshot(id: "scan", title: "Inspect existing shortcut flow", isComplete: true),
                    AgentTaskSnapshot(id: "patch", title: "Patch navigation model", isComplete: false),
                ],
                timeline: [
                    AgentTimelineEntry(kind: .user, title: "Fix panel shortcuts", detail: nil, timestamp: referenceDate.addingTimeInterval(-190)),
                    AgentTimelineEntry(kind: .tool, title: "apply_patch", detail: "Prepared shortcut and focus updates.", timestamp: referenceDate.addingTimeInterval(-140)),
                    AgentTimelineEntry(kind: .assistant, title: "Waiting for approval", detail: "The patch is ready to apply.", timestamp: referenceDate.addingTimeInterval(-120)),
                ],
                workingDirectory: "/Users/demo/Projects/AgentIsland",
                originPath: "/tmp/demo/codex-panel.jsonl",
                resumeCommand: "codex resume codex-panel",
                timestamp: referenceDate.addingTimeInterval(-120)
            ),
            AgentEvent(
                source: .claude,
                sessionId: "claude-hooks",
                threadId: "thread-hooks",
                terminalSessionId: "terminal-claude-3",
                title: "Repair hook installation",
                status: .waitingForInput,
                lastAssistantMessage: "Hooks were modified by another tool. Claude is waiting for your answer.",
                questionPayload: AgentQuestionPayload(
                    prompt: "Restore CLI hooks for Claude Code?",
                    allowsMultipleSelection: false,
                    options: [
                        AgentQuestionOption(id: "restore", title: "Restore now", detail: "Reinstall the managed hook block"),
                        AgentQuestionOption(id: "skip", title: "Skip", detail: "Keep current hook files untouched"),
                    ]
                ),
                tasks: [
                    AgentTaskSnapshot(id: "diff", title: "Compare current settings.json", isComplete: true),
                    AgentTaskSnapshot(id: "repair", title: "Repair hook block", isComplete: false),
                ],
                timeline: [
                    AgentTimelineEntry(kind: .system, title: "Hooks changed", detail: "Claude hook files no longer match the managed configuration.", timestamp: referenceDate.addingTimeInterval(-95)),
                    AgentTimelineEntry(kind: .assistant, title: "Waiting for input", detail: "Claude is asking whether the hooks should be restored.", timestamp: referenceDate.addingTimeInterval(-80)),
                ],
                workingDirectory: "/Users/demo/Projects/AgentIsland",
                originPath: "/tmp/demo/claude-hooks.jsonl",
                timestamp: referenceDate.addingTimeInterval(-80)
            ),
            AgentEvent(
                source: .gemini,
                sessionId: "gemini-localization",
                threadId: "thread-l10n",
                terminalSessionId: "warp-gemini-7",
                title: "Translate onboarding copy",
                status: .runningTool,
                lastAssistantMessage: "Syncing Japanese and Korean onboarding strings.",
                tasks: [
                    AgentTaskSnapshot(id: "extract", title: "Extract English copy", isComplete: true),
                    AgentTaskSnapshot(id: "translate", title: "Translate ja/ko", isComplete: false),
                ],
                timeline: [
                    AgentTimelineEntry(kind: .user, title: "Translate onboarding copy", detail: nil, timestamp: referenceDate.addingTimeInterval(-45)),
                    AgentTimelineEntry(kind: .tool, title: "read_file", detail: "Reading localized resource files.", timestamp: referenceDate.addingTimeInterval(-36)),
                    AgentTimelineEntry(kind: .assistant, title: "Syncing strings", detail: "Updating Japanese and Korean onboarding text.", timestamp: referenceDate.addingTimeInterval(-30)),
                ],
                workingDirectory: "/Users/demo/Projects/AgentIsland",
                originPath: "/tmp/demo/gemini-localization.json",
                timestamp: referenceDate.addingTimeInterval(-30)
            ),
        ]
    }
}
