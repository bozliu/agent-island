import AgentCore
import Foundation

public protocol AgentSourceAdapter: Sendable {
    var source: AgentSource { get }
    var capabilities: AgentSourceCapabilities { get }

    func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession]
    func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult
    func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult
    func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult
    func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent]
    func loadHistory(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentHistoryItem]
    func submitResponse(_ response: String, to session: AgentSession, in environment: AgentEnvironment) async throws -> AgentSubmitResponseResult
    func resolveJumpTarget(for session: AgentSession, in environment: AgentEnvironment) async throws -> AgentJumpTarget?
    func watchPaths(in environment: AgentEnvironment) throws -> [URL]
}

public extension AgentSourceAdapter {
    func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        try await installHooks(in: environment)
    }

    func loadHistory(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentHistoryItem] {
        let events = try await loadEvents(for: session, in: environment)
        return events.map { event in
            AgentHistoryItem(
                kind: event.status == .runningTool ? .tool : .system,
                title: event.title,
                body: event.lastAssistantMessage,
                timestamp: event.timestamp
            )
        }
    }

    func submitResponse(_ response: String, to session: AgentSession, in environment: AgentEnvironment) async throws -> AgentSubmitResponseResult {
        throw NSError(domain: "AgentIsland.SourceAdapters", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "\(source.rawValue) does not support direct submit yet."
        ])
    }

    func resolveJumpTarget(for session: AgentSession, in environment: AgentEnvironment) async throws -> AgentJumpTarget? {
        if let terminalSessionId = session.terminalSessionId {
            let lowered = terminalSessionId.lowercased()
            if lowered.hasPrefix("tmux") {
                return AgentJumpTarget(kind: .tmux, label: session.title, identifier: terminalSessionId)
            }
            if lowered.hasPrefix("cursor") || lowered.hasPrefix("vscode") || lowered.hasPrefix("code") {
                return AgentJumpTarget(kind: .ide, label: session.title, identifier: terminalSessionId)
            }
            return AgentJumpTarget(kind: .terminalSession, label: session.title, identifier: terminalSessionId)
        }
        if let resumeCommand = session.resumeCommand {
            return AgentJumpTarget(kind: .resumeCommand, label: session.title, command: resumeCommand)
        }
        if let workingDirectory = session.workingDirectory {
            return AgentJumpTarget(kind: .workingDirectory, label: session.title, filePath: workingDirectory)
        }
        if let originPath = session.originPath {
            return AgentJumpTarget(kind: .log, label: session.title, filePath: originPath)
        }
        return nil
    }

    func watchPaths(in environment: AgentEnvironment) throws -> [URL] {
        []
    }
}

public enum FixtureAdapterError: Error, LocalizedError {
    case fixtureMissing(URL)

    public var errorDescription: String? {
        switch self {
        case .fixtureMissing(let url):
            return "Fixture not found at \(url.path)"
        }
    }
}

public struct AgentSourceAdapterFactory {
    public static func live(
        fixtureRoot: URL? = nil,
        includeFixtures: Bool = true
    ) -> [any AgentSourceAdapter] {
        let root = fixtureRoot ?? AgentEnvironment.live().fixtureDirectory
        return [
            ClaudeSourceAdapter(fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            CodexSourceAdapter(fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            GeminiSourceAdapter(fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            OpenClawSourceAdapter(fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            CursorSourceAdapter(fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            CopilotSourceAdapter(fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            PlaceholderSourceAdapter(source: .droid, fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            PlaceholderSourceAdapter(source: .qoder, fixtureRoot: root, useFixturesAsFallback: includeFixtures),
            PlaceholderSourceAdapter(source: .codebuddy, fixtureRoot: root, useFixturesAsFallback: includeFixtures),
        ]
    }

    public static func production(fixtureRoot: URL? = nil) -> [any AgentSourceAdapter] {
        live(fixtureRoot: fixtureRoot, includeFixtures: false)
    }
}

private enum FixtureLoader {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func fixtureURLs(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

private typealias JSONObject = [String: Any]

private struct CodexIndexEntry: Decodable {
    let id: String
    let threadName: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
        case updatedAt = "updated_at"
    }
}

private struct ClaudeFixtureEnvelope: Decodable {
    struct EventRecord: Decodable {
        let timestamp: Date
        let type: String
        let text: String?
        let question: ClaudeQuestion?
        let approval: ClaudeApproval?
        let tasks: [AgentTaskSnapshot]?
    }

    struct ClaudeQuestion: Decodable {
        let prompt: String
        let allowsMultipleSelection: Bool
        let options: [AgentQuestionOption]
    }

    struct ClaudeApproval: Decodable {
        let tool: String
        let summary: String
        let choices: [String]
        let files: [AgentApprovalFileChange]
    }

    let sessionId: String
    let title: String
    let terminalSessionId: String?
    let events: [EventRecord]
}

private struct CodexFixtureEnvelope: Decodable {
    struct EventRecord: Decodable {
        let at: Date
        let event: String
        let summary: String?
        let usage: AgentUsageSnapshot?
        let approval: CodexApproval?
        let question: CodexQuestion?
        let subagentParentThreadId: String?
        let agentNickname: String?
        let agentRole: String?
        let tasks: [AgentTaskSnapshot]?
    }

    struct CodexApproval: Decodable {
        let tool: String
        let summary: String
        let choices: [String]
        let files: [AgentApprovalFileChange]
    }

    struct CodexQuestion: Decodable {
        let prompt: String
        let options: [AgentQuestionOption]
    }

    let threadId: String
    let sessionId: String
    let title: String
    let terminalSessionId: String?
    let events: [EventRecord]

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case sessionId = "session_id"
        case title
        case terminalSessionId = "terminal_session_id"
        case events
    }
}

private struct GenericFixtureEnvelope: Decodable {
    struct EventRecord: Decodable {
        let timestamp: Date
        let status: AgentStatus
        let summary: String?
        let tasks: [AgentTaskSnapshot]?
    }

    let sessionId: String
    let title: String
    let terminalSessionId: String?
    let events: [EventRecord]
}

public struct PlaceholderSourceAdapter: AgentSourceAdapter {
    public let source: AgentSource
    private let fixtureRoot: URL
    private let useFixturesAsFallback: Bool
    public let capabilities = AgentSourceCapabilities(
        supportsRealtimeUpdates: false,
        supportsDirectSubmit: false,
        supportsHistory: false,
        supportsJump: false,
        supportsAutoInstall: false
    )

    public init(source: AgentSource, fixtureRoot: URL, useFixturesAsFallback: Bool = true) {
        self.source = source
        self.fixtureRoot = fixtureRoot
        self.useFixturesAsFallback = useFixturesAsFallback
    }

    public func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession] {
        guard useFixturesAsFallback else { return [] }
        let directory = fixtureRoot.appendingPathComponent(source.rawValue, isDirectory: true)
        let urls = try FixtureLoader.fixtureURLs(in: directory)
        return urls.map {
            DiscoveredSession(
                source: source,
                sessionId: $0.deletingPathExtension().lastPathComponent,
                title: "\($0.deletingPathExtension().lastPathComponent) (fixture)",
                fileURL: $0
            )
        }
    }

    public func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        HookInstallationResult(
            source: source,
            status: .manual,
            message: "No open-source live adapter is available for \(source.rawValue) yet.",
            touchedPaths: []
        )
    }

    public func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        try await installHooks(in: environment)
    }

    public func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        HookInstallationResult(
            source: source,
            status: .manual,
            message: "No managed hooks exist for \(source.rawValue).",
            touchedPaths: []
        )
    }

    public func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent] {
        guard let url = session.fileURL else { return [] }
        let data = try Data(contentsOf: url)
        return try FixtureLoader.decoder.decode([AgentEvent].self, from: data)
    }
}

public struct ClaudeSourceAdapter: AgentSourceAdapter {
    public let source: AgentSource = .claude
    private let fixtureRoot: URL
    private let useFixturesAsFallback: Bool
    public let capabilities = AgentSourceCapabilities(
        supportsRealtimeUpdates: true,
        supportsDirectSubmit: true,
        supportsHistory: true,
        supportsJump: true,
        supportsAutoInstall: true
    )

    public init(fixtureRoot: URL, useFixturesAsFallback: Bool = true) {
        self.fixtureRoot = fixtureRoot
        self.useFixturesAsFallback = useFixturesAsFallback
    }

    public func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession] {
        let live = try discoverCapturedSessions(for: source, in: environment)
        if live.isEmpty == false {
            return live
        }
        guard useFixturesAsFallback else { return [] }
        return try discoverFixtureClaudeSessions(using: fixtureRoot.appendingPathComponent("claude", isDirectory: true))
    }

    public func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let script = try ensureClaudeSocketClient(in: environment)
        let command = "\(detectPython()) \(script.path)"
        let settingsURL = claudeSettingsURL(in: environment)
        let installed = claudeHookStateMatches(at: settingsURL, command: command)
        return HookInstallationResult(
            source: source,
            status: installed ? .installed : .manual,
            message: installed ? "Claude hooks are installed and pointing at this workspace build." : "Claude hooks can be repaired to point at this workspace build.",
            touchedPaths: [settingsURL.path, script.path]
        )
    }

    public func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let script = try ensureClaudeSocketClient(in: environment)
        let command = "\(detectPython()) \(script.path)"
        let settingsURL = claudeSettingsURL(in: environment)
        try ensureClaudeHooks(at: settingsURL, command: command)
        return HookInstallationResult(
            source: source,
            status: .repaired,
            message: "Claude hooks now point at the current Agent Island bridge.",
            touchedPaths: [settingsURL.path, script.path]
        )
    }

    public func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let settingsURL = claudeSettingsURL(in: environment)
        try removeClaudeHooks(at: settingsURL)
        return HookInstallationResult(
            source: source,
            status: .manual,
            message: "Claude managed hooks were removed.",
            touchedPaths: [settingsURL.path]
        )
    }

    public func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent] {
        guard isFixtureSession(session, fixtureRoot: fixtureRoot) == false else {
            let envelope: ClaudeFixtureEnvelope = try loadFixtureEnvelope(for: session, sourceDirectory: "claude")
            return envelope.events.map { record in
                AgentEvent(
                    source: source,
                    sessionId: envelope.sessionId,
                    terminalSessionId: envelope.terminalSessionId,
                    title: envelope.title,
                    status: parseClaudeStatus(record.type),
                    lastAssistantMessage: record.text,
                    questionPayload: record.question.map {
                        AgentQuestionPayload(
                            prompt: $0.prompt,
                            allowsMultipleSelection: $0.allowsMultipleSelection,
                            options: $0.options
                        )
                    },
                    approvalPayload: record.approval.map {
                        AgentApprovalPayload(
                            toolName: $0.tool,
                            summary: $0.summary,
                            choices: $0.choices,
                            fileChanges: $0.files
                        )
                    },
                    tasks: record.tasks ?? [],
                    timestamp: record.timestamp
                )
            }
        }

        let captures = try loadCapturedEvents(for: source, in: environment)
            .filter { captureSessionKey($0) == session.sessionId }
            .sorted { $0.timestamp < $1.timestamp }
        guard captures.isEmpty == false else { return [] }
        return [aggregateCapturedSession(session: session, captures: captures)]
    }

    public func loadHistory(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentHistoryItem] {
        let captures = try loadCapturedEvents(for: source, in: environment)
            .filter { captureSessionKey($0) == session.sessionId }
            .sorted { $0.timestamp < $1.timestamp }

        return captures.map { capture in
            AgentHistoryItem(
                kind: capture.status == .runningTool ? .tool : capture.status.needsAttention ? .system : .assistant,
                title: compactWhitespace(capture.message ?? capture.toolName ?? capture.hookName ?? session.title) ?? session.title,
                body: capture.rawInput,
                timestamp: capture.timestamp
            )
        }
    }

    public func submitResponse(_ response: String, to session: AgentSession, in environment: AgentEnvironment) async throws -> AgentSubmitResponseResult {
        let command = [
            "/opt/homebrew/opt/node@24/bin/node",
            "/opt/homebrew/bin/claude",
            "--resume",
            session.sessionId,
            "--print",
            response,
        ]
        try runDetached(command, workingDirectory: session.workingDirectory)
        return AgentSubmitResponseResult(submittedDirectly: true, summary: "Submitted directly to Claude.")
    }

    public func watchPaths(in environment: AgentEnvironment) throws -> [URL] {
        [bridgeCaptureDirectory(for: source, in: environment)]
    }
}

public struct CodexSourceAdapter: AgentSourceAdapter {
    public let source: AgentSource = .codex
    private let fixtureRoot: URL
    private let useFixturesAsFallback: Bool
    public let capabilities = AgentSourceCapabilities(
        supportsRealtimeUpdates: true,
        supportsDirectSubmit: true,
        supportsHistory: true,
        supportsJump: true,
        supportsAutoInstall: true
    )

    public init(fixtureRoot: URL, useFixturesAsFallback: Bool = true) {
        self.fixtureRoot = fixtureRoot
        self.useFixturesAsFallback = useFixturesAsFallback
    }

    public func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession] {
        let live = try discoverLiveCodexSessions(in: environment)
        if live.isEmpty == false {
            return live
        }
        guard useFixturesAsFallback else { return [] }
        return try loadFixtureCodexSessions(from: fixtureRoot.appendingPathComponent("codex", isDirectory: true))
    }

    public func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let launcher = try ensureBridgeLauncher(in: environment)
        let command = "\(launcher.path) --source \(source.rawValue)"
        let hooksURL = codexHooksURL(in: environment)
        let configURL = codexConfigURL(in: environment)
        let installed = hookCommandExists(at: hooksURL, command: command) && codexHooksEnabled(at: configURL)
        return HookInstallationResult(
            source: source,
            status: installed ? .installed : .manual,
            message: installed ? "Codex hooks are installed and codex_hooks is enabled." : "Codex hook files can be repaired automatically.",
            touchedPaths: [hooksURL.path, configURL.path, launcher.path]
        )
    }

    public func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let launcher = try ensureBridgeLauncher(in: environment)
        let command = "\(launcher.path) --source \(source.rawValue)"
        let hooksURL = codexHooksURL(in: environment)
        let configURL = codexConfigURL(in: environment)
        try ensureCodexHooks(at: hooksURL, command: command)
        try ensureCodexConfig(at: configURL)
        return HookInstallationResult(
            source: source,
            status: .repaired,
            message: "Codex hooks now point at the current Agent Island bridge and codex_hooks is enabled.",
            touchedPaths: [hooksURL.path, configURL.path, launcher.path]
        )
    }

    public func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let hooksURL = codexHooksURL(in: environment)
        let configURL = codexConfigURL(in: environment)
        try removeCodexHooks(at: hooksURL)
        try removeCodexConfig(at: configURL)
        return HookInstallationResult(
            source: source,
            status: .manual,
            message: "Codex managed hooks were removed.",
            touchedPaths: [hooksURL.path, configURL.path]
        )
    }

    public func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent] {
        guard isFixtureSession(session, fixtureRoot: fixtureRoot) == false else {
            let envelope = try FixtureLoader.decoder.decode(CodexFixtureEnvelope.self, from: Data(contentsOf: try fixtureURL(for: session, sourceDirectory: "codex")))
            return envelope.events.map { record in
                AgentEvent(
                    source: source,
                    sessionId: envelope.sessionId,
                    threadId: envelope.threadId,
                    terminalSessionId: envelope.terminalSessionId,
                    title: envelope.title,
                    status: parseCodexStatus(record.event),
                    lastAssistantMessage: record.summary,
                    questionPayload: record.question.map {
                        AgentQuestionPayload(prompt: $0.prompt, allowsMultipleSelection: false, options: $0.options)
                    },
                    approvalPayload: record.approval.map {
                        AgentApprovalPayload(
                            toolName: $0.tool,
                            summary: $0.summary,
                            choices: $0.choices,
                            fileChanges: $0.files
                        )
                    },
                    usage: record.usage,
                    subagentParentThreadId: record.subagentParentThreadId,
                    agentNickname: record.agentNickname,
                    agentRole: record.agentRole,
                    tasks: record.tasks ?? [],
                    timestamp: record.at
                )
            }
        }

        guard let url = session.fileURL else { return [] }
        return [try aggregateCodexSession(from: url, discoveredSession: session)]
    }

    public func loadHistory(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentHistoryItem] {
        guard let url = session.fileURL else { return [] }
        let lines = try readCodexRolloutLines(from: url)
        return try codexHistoryItems(from: lines)
    }

    public func submitResponse(_ response: String, to session: AgentSession, in environment: AgentEnvironment) async throws -> AgentSubmitResponseResult {
        let command = session.resumeCommand ?? shellCommand(
            executable: "codex",
            arguments: ["resume", session.sessionId, response],
            workingDirectory: session.workingDirectory
        )
        try runDetached(["/bin/zsh", "-lc", command], workingDirectory: session.workingDirectory)
        return AgentSubmitResponseResult(submittedDirectly: true, summary: "Submitted directly to Codex.")
    }

    public func watchPaths(in environment: AgentEnvironment) throws -> [URL] {
        [environment.homeDirectory.appendingPathComponent(".codex/session_index.jsonl")]
    }
}

public struct GeminiSourceAdapter: AgentSourceAdapter {
    public let source: AgentSource = .gemini
    private let fixtureRoot: URL
    private let useFixturesAsFallback: Bool
    public let capabilities = AgentSourceCapabilities(
        supportsRealtimeUpdates: true,
        supportsDirectSubmit: true,
        supportsHistory: true,
        supportsJump: true,
        supportsAutoInstall: true
    )

    public init(fixtureRoot: URL, useFixturesAsFallback: Bool = true) {
        self.fixtureRoot = fixtureRoot
        self.useFixturesAsFallback = useFixturesAsFallback
    }

    public func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession] {
        let live = try discoverLiveGeminiSessions(in: environment)
        if live.isEmpty == false {
            return live
        }
        guard useFixturesAsFallback else { return [] }
        return try genericSessions(from: fixtureRoot.appendingPathComponent("gemini", isDirectory: true), source: source)
    }

    public func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let launcher = try ensureBridgeLauncher(in: environment)
        let command = "\(launcher.path) --source \(source.rawValue)"
        let settingsURL = geminiSettingsURL(in: environment)
        let installed = hookCommandExists(at: settingsURL, command: command)
        return HookInstallationResult(
            source: source,
            status: installed ? .installed : .manual,
            message: installed ? "Gemini hooks are installed and pointing at this workspace build." : "Gemini hooks can be repaired to point at this workspace build.",
            touchedPaths: [settingsURL.path, launcher.path]
        )
    }

    public func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let launcher = try ensureBridgeLauncher(in: environment)
        let command = "\(launcher.path) --source \(source.rawValue)"
        let settingsURL = geminiSettingsURL(in: environment)
        try ensureGeminiHooks(at: settingsURL, command: command)
        return HookInstallationResult(
            source: source,
            status: .repaired,
            message: "Gemini hooks now point at the current Agent Island bridge.",
            touchedPaths: [settingsURL.path, launcher.path]
        )
    }

    public func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let settingsURL = geminiSettingsURL(in: environment)
        try removeGeminiHooks(at: settingsURL)
        return HookInstallationResult(
            source: source,
            status: .manual,
            message: "Gemini managed hooks were removed.",
            touchedPaths: [settingsURL.path]
        )
    }

    public func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent] {
        guard isFixtureSession(session, fixtureRoot: fixtureRoot) == false else {
            return try loadGenericFixtureEvents(for: session, source: source)
        }
        guard let url = session.fileURL else { return [] }
        return [try aggregateGeminiSession(from: url, discoveredSession: session)]
    }

    public func loadHistory(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentHistoryItem] {
        guard let url = session.fileURL else { return [] }
        return try geminiHistoryItems(from: url)
    }

    public func submitResponse(_ response: String, to session: AgentSession, in environment: AgentEnvironment) async throws -> AgentSubmitResponseResult {
        try runDetached(
            ["gemini", "--resume", session.sessionId, "--prompt", response],
            workingDirectory: session.workingDirectory
        )
        return AgentSubmitResponseResult(submittedDirectly: true, summary: "Submitted directly to Gemini.")
    }

    public func watchPaths(in environment: AgentEnvironment) throws -> [URL] {
        [environment.homeDirectory.appendingPathComponent(".gemini/tmp")]
    }
}

public struct OpenClawSourceAdapter: AgentSourceAdapter {
    public let source: AgentSource = .openclaw
    private let fixtureRoot: URL
    private let useFixturesAsFallback: Bool
    public let capabilities = AgentSourceCapabilities(
        supportsRealtimeUpdates: true,
        supportsDirectSubmit: true,
        supportsHistory: true,
        supportsJump: true,
        supportsAutoInstall: false
    )

    public init(fixtureRoot: URL, useFixturesAsFallback: Bool = true) {
        self.fixtureRoot = fixtureRoot
        self.useFixturesAsFallback = useFixturesAsFallback
    }

    public func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession] {
        let captured = try discoverCapturedSessions(for: source, in: environment)
        if captured.isEmpty == false {
            return captured
        }

        let live = try discoverLiveOpenClawSessions(in: environment)
        if live.isEmpty == false {
            return live
        }

        guard useFixturesAsFallback else { return [] }
        return try genericSessions(from: fixtureRoot.appendingPathComponent("openclaw", isDirectory: true), source: source)
    }

    public func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        let pluginURL = openClawPluginURL(in: environment)
        let installed = FileManager.default.fileExists(atPath: pluginURL.path)
        return HookInstallationResult(
            source: source,
            status: installed ? .installed : .manual,
            message: installed ? "OpenCode realtime plugin is installed and can stream to the Agent Island socket." : "OpenCode plugin was not found. Install the Agent Island plugin in ~/.config/opencode/plugins first.",
            touchedPaths: [pluginURL.path, openClawDatabaseURL(in: environment).path]
        )
    }

    public func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        try await installHooks(in: environment)
    }

    public func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        HookInstallationResult(
            source: source,
            status: .manual,
            message: "OpenCode plugin rollback is not managed by the OSS build yet.",
            touchedPaths: [openClawPluginURL(in: environment).path]
        )
    }

    public func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent] {
        guard isFixtureSession(session, fixtureRoot: fixtureRoot) == false else {
            return try loadGenericFixtureEvents(for: session, source: source)
        }

        let captures = try loadCapturedEvents(for: source, in: environment)
            .filter { captureSessionKey($0) == session.sessionId }
            .sorted { $0.timestamp < $1.timestamp }
        if captures.isEmpty == false {
            return [aggregateOpenClawCapturedSession(session: session, captures: captures)]
        }

        if let snapshot = try loadOpenClawSessionSnapshot(sessionId: session.sessionId, in: environment) {
            return [snapshot]
        }

        return []
    }

    public func loadHistory(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentHistoryItem] {
        let captures = try loadCapturedEvents(for: source, in: environment)
            .filter { captureSessionKey($0) == session.sessionId }
            .sorted { $0.timestamp < $1.timestamp }
        if captures.isEmpty == false {
            return captures.map { capture in
                AgentHistoryItem(
                    kind: capture.status == .runningTool ? .tool : .system,
                    title: compactWhitespace(capture.message ?? capture.toolName ?? capture.hookName ?? session.title) ?? session.title,
                    body: capture.metadata["detail"],
                    timestamp: capture.timestamp
                )
            }
        }
        return try loadOpenClawHistory(sessionId: session.sessionId, in: environment)
    }

    public func submitResponse(_ response: String, to session: AgentSession, in environment: AgentEnvironment) async throws -> AgentSubmitResponseResult {
        guard let resumeCommand = session.resumeCommand, resumeCommand.isEmpty == false else {
            return AgentSubmitResponseResult(submittedDirectly: false, summary: "OpenCode is waiting for the live socket bridge.")
        }
        try runDetached(["/bin/zsh", "-lc", "\(resumeCommand) \(shellEscape(response))"], workingDirectory: session.workingDirectory)
        return AgentSubmitResponseResult(submittedDirectly: true, summary: "Submitted directly to OpenCode.")
    }

    public func watchPaths(in environment: AgentEnvironment) throws -> [URL] {
        [
            bridgeCaptureDirectory(for: source, in: environment),
            openClawDatabaseURL(in: environment),
        ]
    }
}

public struct CursorSourceAdapter: AgentSourceAdapter {
    public let source: AgentSource = .cursor
    private let fixtureRoot: URL
    private let useFixturesAsFallback: Bool
    public let capabilities = AgentSourceCapabilities(
        supportsRealtimeUpdates: false,
        supportsDirectSubmit: false,
        supportsHistory: false,
        supportsJump: true,
        supportsAutoInstall: true
    )

    public init(fixtureRoot: URL, useFixturesAsFallback: Bool = true) {
        self.fixtureRoot = fixtureRoot
        self.useFixturesAsFallback = useFixturesAsFallback
    }

    public func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession] {
        guard useFixturesAsFallback else { return [] }
        return try genericSessions(from: fixtureRoot.appendingPathComponent("cursor", isDirectory: true), source: source)
    }

    public func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        HookInstallationResult(
            source: source,
            status: .manual,
            message: "Cursor can surface jump targets through the shared IDE bridge, but no live OSS adapter exists yet.",
            touchedPaths: ["Extensions/terminal-focus"]
        )
    }

    public func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        try await installHooks(in: environment)
    }

    public func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        HookInstallationResult(
            source: source,
            status: .manual,
            message: "Cursor bridge rollback is not implemented yet.",
            touchedPaths: ["Extensions/terminal-focus"]
        )
    }

    public func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent] {
        try loadGenericFixtureEvents(for: session, source: source)
    }
}

public struct CopilotSourceAdapter: AgentSourceAdapter {
    public let source: AgentSource = .copilot
    private let fixtureRoot: URL
    private let useFixturesAsFallback: Bool
    public let capabilities = AgentSourceCapabilities(
        supportsRealtimeUpdates: false,
        supportsDirectSubmit: false,
        supportsHistory: false,
        supportsJump: true,
        supportsAutoInstall: true
    )

    public init(fixtureRoot: URL, useFixturesAsFallback: Bool = true) {
        self.fixtureRoot = fixtureRoot
        self.useFixturesAsFallback = useFixturesAsFallback
    }

    public func discoverSessions(in environment: AgentEnvironment) async throws -> [DiscoveredSession] {
        guard useFixturesAsFallback else { return [] }
        return try genericSessions(from: fixtureRoot.appendingPathComponent("copilot", isDirectory: true), source: source)
    }

    public func installHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        HookInstallationResult(
            source: source,
            status: .manual,
            message: "Copilot does not expose a public local session feed that the OSS build can read yet.",
            touchedPaths: []
        )
    }

    public func repairHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        try await installHooks(in: environment)
    }

    public func rollbackHooks(in environment: AgentEnvironment) async throws -> HookInstallationResult {
        HookInstallationResult(
            source: source,
            status: .manual,
            message: "Copilot bridge rollback is not implemented yet.",
            touchedPaths: []
        )
    }

    public func loadEvents(for session: DiscoveredSession, in environment: AgentEnvironment) async throws -> [AgentEvent] {
        try loadGenericFixtureEvents(for: session, source: source)
    }
}

private func parseClaudeStatus(_ raw: String) -> AgentStatus {
    switch raw {
    case "thinking":
        .thinking
    case "running_tool":
        .runningTool
    case "question":
        .waitingForInput
    case "approval":
        .waitingForApproval
    case "done":
        .complete
    default:
        .idle
    }
}

private func parseCodexStatus(_ raw: String) -> AgentStatus {
    switch raw {
    case "session_start", "thinking":
        .thinking
    case "tool_start":
        .runningTool
    case "approval_required":
        .waitingForApproval
    case "question":
        .waitingForInput
    case "compacting":
        .compacting
    case "error":
        .error
    case "completed":
        .complete
    default:
        .idle
    }
}

private func discoverFixtureClaudeSessions(using directory: URL) throws -> [DiscoveredSession] {
    let urls = try FixtureLoader.fixtureURLs(in: directory)
    return try urls.map { url in
        let envelope = try FixtureLoader.decoder.decode(ClaudeFixtureEnvelope.self, from: Data(contentsOf: url))
        return DiscoveredSession(
            source: .claude,
            sessionId: envelope.sessionId,
            title: envelope.title,
            terminalSessionId: envelope.terminalSessionId,
            fileURL: url
        )
    }
}

private func loadFixtureCodexSessions(from directory: URL) throws -> [DiscoveredSession] {
    let urls = try FixtureLoader.fixtureURLs(in: directory)
    return try urls.map { url in
        let envelope = try FixtureLoader.decoder.decode(CodexFixtureEnvelope.self, from: Data(contentsOf: url))
        return DiscoveredSession(
            source: .codex,
            sessionId: envelope.sessionId,
            title: envelope.title,
            threadId: envelope.threadId,
            terminalSessionId: envelope.terminalSessionId,
            fileURL: url
        )
    }
}

private func genericSessions(from directory: URL, source: AgentSource) throws -> [DiscoveredSession] {
    let urls = try FixtureLoader.fixtureURLs(in: directory)
    return try urls.map { url in
        let envelope = try FixtureLoader.decoder.decode(GenericFixtureEnvelope.self, from: Data(contentsOf: url))
        return DiscoveredSession(
            source: source,
            sessionId: envelope.sessionId,
            title: envelope.title,
            terminalSessionId: envelope.terminalSessionId,
            fileURL: url
        )
    }
}

private func loadGenericFixtureEvents(for session: DiscoveredSession, source: AgentSource) throws -> [AgentEvent] {
    let envelope = try FixtureLoader.decoder.decode(GenericFixtureEnvelope.self, from: Data(contentsOf: try fixtureURL(for: session, sourceDirectory: source.rawValue)))
    return envelope.events.map { record in
        AgentEvent(
            source: source,
            sessionId: envelope.sessionId,
            terminalSessionId: envelope.terminalSessionId,
            title: envelope.title,
            status: record.status,
            lastAssistantMessage: record.summary,
            tasks: record.tasks ?? [],
            timestamp: record.timestamp
        )
    }
}

private func discoverLiveOpenClawSessions(in environment: AgentEnvironment) throws -> [DiscoveredSession] {
    let rows = try sqliteJSONRows(
        databaseURL: openClawDatabaseURL(in: environment),
        query: """
        select id, title, directory, time_updated, time_archived
        from session
        where time_archived is null
        order by time_updated desc
        limit 8;
        """
    )

    return rows.compactMap { row in
        guard let rawID = row.string("id"), rawID.isEmpty == false else { return nil }
        let title = compactWhitespace(row.string("title")) ?? rawID
        return DiscoveredSession(
            source: .openclaw,
            sessionId: prefixedOpenClawSessionID(rawID),
            title: shortened(title, limit: 70)
        )
    }
}

private func loadOpenClawSessionSnapshot(sessionId: String, in environment: AgentEnvironment) throws -> AgentEvent? {
    let rawSessionID = rawOpenClawSessionID(from: sessionId)
    let rows = try sqliteJSONRows(
        databaseURL: openClawDatabaseURL(in: environment),
        query: """
        select id, title, directory, time_updated, time_archived, permission
        from session
        where id = \(sqliteQuoted(rawSessionID))
        limit 1;
        """
    )
    guard let row = rows.first else { return nil }

    let title = compactWhitespace(row.string("title")) ?? rawSessionID
    let directory = compactWhitespace(row.string("directory"))
    let timestamp = sqliteTimestamp(row.int("time_updated"))
    let archivedAt = row.int("time_archived")
    let status: AgentStatus = archivedAt == nil ? .thinking : .complete
    let lastAssistantMessage = try latestOpenClawTextPart(sessionId: rawSessionID, in: environment)

    return AgentEvent(
        source: .openclaw,
        sessionId: prefixedOpenClawSessionID(rawSessionID),
        title: title,
        status: status,
        lastAssistantMessage: lastAssistantMessage,
        workingDirectory: directory,
        timestamp: timestamp
    )
}

private func loadOpenClawHistory(sessionId: String, in environment: AgentEnvironment) throws -> [AgentHistoryItem] {
    let rawSessionID = rawOpenClawSessionID(from: sessionId)
    let rows = try sqliteJSONRows(
        databaseURL: openClawDatabaseURL(in: environment),
        query: """
        select data, time_updated
        from part
        where session_id = \(sqliteQuoted(rawSessionID))
        order by time_updated asc
        limit 200;
        """
    )

    return rows.compactMap { row in
        guard let dataString = row.string("data"), let data = dataString.data(using: .utf8) else { return nil }
        guard let object = try? jsonObject(from: data) else { return nil }
        let timestamp = sqliteTimestamp(row.int("time_updated"))

        if let type = object.string("type"), type == "tool" {
            let title = compactWhitespace(object.string("tool") ?? object.string("name") ?? "tool") ?? "tool"
            let detail = compactWhitespace(object.dictionary("state")?.string("status"))
            return AgentHistoryItem(kind: .tool, title: title, body: detail, timestamp: timestamp)
        }

        if let text = compactWhitespace(object.string("text") ?? object.dictionary("state")?.string("text")), text.isEmpty == false {
            let role = object.string("role")?.lowercased()
            let kind: AgentHistoryItemKind = role == "user" ? .user : .assistant
            return AgentHistoryItem(kind: kind, title: firstLine(of: text), body: text, timestamp: timestamp)
        }

        return nil
    }
}

private func latestOpenClawTextPart(sessionId: String, in environment: AgentEnvironment) throws -> String? {
    let rows = try sqliteJSONRows(
        databaseURL: openClawDatabaseURL(in: environment),
        query: """
        select data
        from part
        where session_id = \(sqliteQuoted(sessionId))
        order by time_updated desc
        limit 20;
        """
    )

    for row in rows {
        guard let dataString = row.string("data"), let data = dataString.data(using: .utf8) else { continue }
        guard let object = try? jsonObject(from: data) else { continue }
        if let text = compactWhitespace(object.string("text") ?? object.dictionary("state")?.string("text")), text.isEmpty == false {
            return text
        }
    }

    return nil
}

private func aggregateOpenClawCapturedSession(session: DiscoveredSession, captures: [AgentBridgeCapture]) -> AgentEvent {
    let latest = captures.max(by: { $0.timestamp < $1.timestamp })!
    let timeline = captures.map { capture in
        AgentTimelineEntry(
            kind: captureTimelineKind(capture.status),
            title: compactWhitespace(capture.message ?? capture.toolName ?? capture.hookName ?? session.title) ?? session.title,
            detail: capture.metadata["detail"] ?? capture.hookName,
            timestamp: capture.timestamp
        )
    }

    let questionPayload: AgentQuestionPayload?
    if latest.metadata["request_kind"] == "question" {
        let prompt = latest.metadata["question_prompt"] ?? compactWhitespace(latest.message) ?? "Question"
        let options = (try? jsonArrayOfStrings(from: latest.metadata["question_options"])) ?? []
        questionPayload = AgentQuestionPayload(
            prompt: prompt,
            allowsMultipleSelection: false,
            options: options.enumerated().map { index, option in
                AgentQuestionOption(id: "openclaw-q-\(index)", title: option)
            }
        )
    } else {
        questionPayload = nil
    }

    let approvalPayload: AgentApprovalPayload?
    if latest.metadata["request_kind"] == "approval" || latest.status == .waitingForApproval {
        approvalPayload = AgentApprovalPayload(
            toolName: latest.toolName ?? "OpenCode Permission",
            summary: latest.message ?? latest.metadata["detail"] ?? "OpenCode is waiting for a permission decision.",
            choices: ["Allow once", "Always allow", "Deny"],
            fileChanges: []
        )
    } else {
        approvalPayload = nil
    }

    return AgentEvent(
        source: .openclaw,
        sessionId: session.sessionId,
        title: session.title,
        status: latest.status,
        lastAssistantMessage: compactWhitespace(latest.message),
        questionPayload: questionPayload,
        approvalPayload: approvalPayload,
        tasks: makeToolTasks(from: timeline, running: latest.status == .runningTool),
        timeline: Array(timeline.suffix(18)),
        workingDirectory: compactWhitespace(latest.cwd),
        timestamp: latest.timestamp
    )
}

private func fixtureURL(for session: DiscoveredSession, sourceDirectory: String) throws -> URL {
    guard let url = session.fileURL else {
        throw FixtureAdapterError.fixtureMissing(URL(fileURLWithPath: sourceDirectory))
    }
    return url
}

private func loadFixtureEnvelope<T: Decodable>(for session: DiscoveredSession, sourceDirectory: String) throws -> T {
    try FixtureLoader.decoder.decode(T.self, from: Data(contentsOf: try fixtureURL(for: session, sourceDirectory: sourceDirectory)))
}

private func discoverLiveCodexSessions(in environment: AgentEnvironment) throws -> [DiscoveredSession] {
    let indexURL = environment.homeDirectory.appendingPathComponent(".codex/session_index.jsonl")
    guard FileManager.default.fileExists(atPath: indexURL.path) else {
        return []
    }

    let decoder = FixtureLoader.decoder
    let lines = try String(contentsOf: indexURL, encoding: .utf8).split(whereSeparator: \.isNewline)
    let entries: [CodexIndexEntry] = try lines.compactMap { line in
        guard line.isEmpty == false else { return nil }
        return try decoder.decode(CodexIndexEntry.self, from: Data(line.utf8))
    }
    let recentEntries = Array(
        entries
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(8)
    )
    let rolloutMap = try discoverCodexRolloutURLs(
        in: environment,
        matchingSessionIDs: Set(recentEntries.map(\.id))
    )
    return recentEntries
        .compactMap { entry in
            guard let url = rolloutMap[entry.id] else { return nil }
            let title = compactWhitespace(entry.threadName ?? entry.id) ?? entry.id
            return DiscoveredSession(
                source: .codex,
                sessionId: entry.id,
                title: title,
                threadId: entry.id,
                fileURL: url
            )
        }
}

private func discoverCodexRolloutURLs(
    in environment: AgentEnvironment,
    matchingSessionIDs: Set<String>
) throws -> [String: URL] {
    let root = environment.homeDirectory.appendingPathComponent(".codex/sessions", isDirectory: true)
    guard FileManager.default.fileExists(atPath: root.path), matchingSessionIDs.isEmpty == false else {
        return [:]
    }

    let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
    var result: [String: URL] = [:]
    var remainingSessionIDs = matchingSessionIDs
    while let next = enumerator?.nextObject() as? URL {
        guard next.pathExtension == "jsonl", next.lastPathComponent.hasPrefix("rollout-") else { continue }
        let filename = next.lastPathComponent
        for sessionID in remainingSessionIDs where filename.contains(sessionID) {
            result[sessionID] = next
            remainingSessionIDs.remove(sessionID)
            break
        }
        if remainingSessionIDs.isEmpty {
            break
        }
    }
    return result
}

private func aggregateCodexSession(from url: URL, discoveredSession: DiscoveredSession) throws -> AgentEvent {
    let lines = try readCodexRolloutLines(from: url)
    var title = discoveredSession.title
    var status: AgentStatus = .thinking
    var lastAssistantMessage: String?
    var usage: AgentUsageSnapshot?
    var threadId = discoveredSession.threadId
    var turnId: String?
    var subagentParentThreadId: String?
    var agentNickname: String?
    var agentRole: String?
    var workingDirectory: String?
    var timestamp = fileModificationDate(for: url)
    var timeline: [AgentTimelineEntry] = []

    for line in lines {
        let lineTimestamp = parseDate(line.string("timestamp")) ?? timestamp
        timestamp = max(timestamp, lineTimestamp)
        switch line.string("type") {
        case "session_meta":
            let payload = line.dictionary("payload")
            threadId = payload?.string("id") ?? threadId
            workingDirectory = payload?.string("cwd") ?? workingDirectory
            agentNickname = payload?.string("agent_nickname") ?? agentNickname
            agentRole = payload?.string("agent_role") ?? agentRole
            if let spawn = payload?.dictionary("source")?.dictionary("subagent")?.dictionary("thread_spawn") {
                subagentParentThreadId = spawn.string("parent_thread_id") ?? subagentParentThreadId
                agentNickname = spawn.string("agent_nickname") ?? agentNickname
                agentRole = spawn.string("agent_role") ?? agentRole
            }
        case "turn_context":
            let payload = line.dictionary("payload")
            turnId = payload?.string("turn_id") ?? turnId
            workingDirectory = payload?.string("cwd") ?? workingDirectory
        case "event_msg":
            let payload = line.dictionary("payload")
            switch payload?.string("type") {
            case "user_message":
                if let message = compactWhitespace(payload?.string("message")) {
                    timeline.append(AgentTimelineEntry(kind: .user, title: message, timestamp: lineTimestamp))
                    status = .thinking
                }
            case "agent_message":
                if let message = compactWhitespace(payload?.string("message")) {
                    lastAssistantMessage = message
                    timeline.append(AgentTimelineEntry(kind: .assistant, title: message, timestamp: lineTimestamp))
                }
            case "token_count":
                usage = parseCodexUsage(payload)
            case "task_complete":
                status = .complete
                if let message = compactWhitespace(payload?.string("last_agent_message")) {
                    lastAssistantMessage = message
                    timeline.append(AgentTimelineEntry(kind: .assistant, title: message, timestamp: lineTimestamp))
                }
            case "turn_aborted":
                status = .interrupted
                timeline.append(AgentTimelineEntry(kind: .system, title: "Turn interrupted", timestamp: lineTimestamp))
            case "thread_rolled_back":
                status = .thinking
                timeline.append(AgentTimelineEntry(kind: .system, title: "Thread rolled back", timestamp: lineTimestamp))
            default:
                break
            }
        case "response_item":
            let payload = line.dictionary("payload")
            switch payload?.string("type") {
            case "function_call", "custom_tool_call", "web_search_call":
                let name = compactWhitespace(payload?.string("name") ?? payload?.dictionary("action")?.string("type") ?? "tool") ?? "tool"
                status = .runningTool
                timeline.append(AgentTimelineEntry(kind: .tool, title: name, detail: "Running", timestamp: lineTimestamp))
            case "function_call_output", "custom_tool_call_output":
                if let output = compactWhitespace(payload?.string("output")), output.isEmpty == false {
                    timeline.append(AgentTimelineEntry(kind: .system, title: firstLine(of: output), detail: nil, timestamp: lineTimestamp))
                }
            case "message":
                if payload?.string("role") == "assistant", let text = firstContentText(payload?.array("content")) {
                    lastAssistantMessage = compactWhitespace(text)
                }
            case "reasoning":
                break
            default:
                break
            }
        case "compacted":
            status = .compacting
            timeline.append(AgentTimelineEntry(kind: .system, title: "Session compacted", timestamp: lineTimestamp))
        default:
            break
        }
    }

    if title.isEmpty {
        title = firstUserTitle(from: timeline) ?? discoveredSession.sessionId
    }
    let tasks = makeToolTasks(from: timeline, running: status == .runningTool)
    let resumeCommand = makeCodexResumeCommand(sessionId: discoveredSession.sessionId, cwd: workingDirectory)
    return AgentEvent(
        source: .codex,
        sessionId: discoveredSession.sessionId,
        threadId: threadId,
        turnId: turnId,
        title: title,
        status: status,
        lastAssistantMessage: lastAssistantMessage,
        usage: usage,
        subagentParentThreadId: subagentParentThreadId,
        agentNickname: agentNickname,
        agentRole: agentRole,
        tasks: tasks,
        timeline: Array(timeline.suffix(18)),
        workingDirectory: workingDirectory,
        originPath: url.path,
        resumeCommand: resumeCommand,
        timestamp: timestamp
    )
}

private func parseCodexUsage(_ payload: JSONObject?) -> AgentUsageSnapshot? {
    guard let info = payload?.dictionary("info") else { return nil }
    let total = info.dictionary("total_token_usage")
    return AgentUsageSnapshot(
        promptTokens: total?.int("input_tokens") ?? total?.int("inputTokens"),
        completionTokens: total?.int("output_tokens") ?? total?.int("outputTokens"),
        totalTokens: total?.int("total_tokens") ?? total?.int("totalTokens")
    )
}

private func makeCodexResumeCommand(sessionId: String, cwd: String?) -> String {
    let base = "codex resume \(shellEscape(sessionId))"
    guard let cwd, cwd.isEmpty == false else {
        return base
    }
    return "cd \(shellEscape(cwd)) && \(base)"
}

private func discoverLiveGeminiSessions(in environment: AgentEnvironment) throws -> [DiscoveredSession] {
    let root = environment.homeDirectory.appendingPathComponent(".gemini/tmp", isDirectory: true)
    guard FileManager.default.fileExists(atPath: root.path) else {
        return []
    }

    let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey])
    var sessions: [(Date, DiscoveredSession)] = []
    while let next = enumerator?.nextObject() as? URL {
        guard next.lastPathComponent.hasPrefix("session-"), next.pathExtension == "json" else { continue }
        let object = try jsonObject(from: Data(contentsOf: next))
        let sessionId = object.string("sessionId") ?? next.deletingPathExtension().lastPathComponent
        let lastUpdated = parseDate(object.string("lastUpdated")) ?? fileModificationDate(for: next)
        let title = geminiTitle(from: object) ?? sessionId
        sessions.append((
            lastUpdated,
            DiscoveredSession(
                source: .gemini,
                sessionId: sessionId,
                title: title,
                fileURL: next
            )
        ))
    }
    return sessions.sorted { $0.0 > $1.0 }.prefix(24).map(\.1)
}

private func aggregateGeminiSession(from url: URL, discoveredSession: DiscoveredSession) throws -> AgentEvent {
    let object = try jsonObject(from: Data(contentsOf: url))
    let messages = object.array("messages") ?? []
    let timestamp = parseDate(object.string("lastUpdated")) ?? fileModificationDate(for: url)
    let projectRoot = geminiProjectRoot(for: url)
    var timeline: [AgentTimelineEntry] = []
    var lastAssistantMessage: String?
    var tasks: [AgentTaskSnapshot] = []
    var usage: AgentUsageSnapshot?
    var status: AgentStatus = .idle

    for raw in messages {
        guard let message = raw as? JSONObject else { continue }
        let messageTimestamp = parseDate(message.string("timestamp")) ?? timestamp
        let type = message.string("type") ?? "system"
        let text = compactWhitespace(geminiMessageText(from: message))
        switch type {
        case "user":
            if let text {
                timeline.append(AgentTimelineEntry(kind: .user, title: text, timestamp: messageTimestamp))
            }
            status = .thinking
        case "gemini":
            if let text {
                lastAssistantMessage = text
                timeline.append(AgentTimelineEntry(kind: .assistant, title: text, timestamp: messageTimestamp))
            }
            let toolCalls = geminiToolCalls(from: message)
            if toolCalls.isEmpty == false {
                status = .runningTool
                tasks = toolCalls.enumerated().map { index, toolCall in
                    AgentTaskSnapshot(
                        id: toolCall.id ?? "\(discoveredSession.sessionId)-tool-\(index)",
                        title: toolCall.title,
                        isComplete: toolCall.isComplete
                    )
                }
                timeline.append(contentsOf: toolCalls.map {
                    AgentTimelineEntry(kind: .tool, title: $0.title, detail: $0.detail, timestamp: messageTimestamp)
                })
            } else {
                status = .complete
            }
            if let tokens = message.dictionary("tokens") {
                usage = AgentUsageSnapshot(
                    promptTokens: tokens.int("input"),
                    completionTokens: tokens.int("output"),
                    totalTokens: tokens.int("total")
                )
            }
        default:
            if let text {
                timeline.append(AgentTimelineEntry(kind: .system, title: text, timestamp: messageTimestamp))
            }
        }
    }

    let title = geminiTitle(from: object) ?? discoveredSession.title
    return AgentEvent(
        source: .gemini,
        sessionId: discoveredSession.sessionId,
        title: title,
        status: status,
        lastAssistantMessage: lastAssistantMessage,
        usage: usage,
        tasks: tasks,
        timeline: Array(timeline.suffix(18)),
        workingDirectory: projectRoot,
        originPath: url.path,
        timestamp: timestamp
    )
}

private struct GeminiToolCallViewModel {
    let id: String?
    let title: String
    let detail: String?
    let isComplete: Bool
}

private func geminiToolCalls(from message: JSONObject) -> [GeminiToolCallViewModel] {
    (message.array("toolCalls") ?? []).compactMap { raw in
        guard let toolCall = raw as? JSONObject else { return nil }
        let status = toolCall.string("status")?.lowercased() ?? ""
        let args = compactWhitespace(toolCall.string("args"))
        let result = compactWhitespace(toolCall.string("result"))
        let title = compactWhitespace(toolCall.string("displayName") ?? toolCall.string("name") ?? "tool") ?? "tool"
        return GeminiToolCallViewModel(
            id: toolCall.string("id"),
            title: title,
            detail: result ?? args,
            isComplete: ["success", "completed", "ok", "done"].contains(status)
        )
    }
}

private func geminiTitle(from object: JSONObject) -> String? {
    let messages = object.array("messages") ?? []
    for raw in messages {
        guard let message = raw as? JSONObject else { continue }
        if message.string("type") == "user", let text = compactWhitespace(geminiMessageText(from: message)), text.isEmpty == false {
            return shortened(text, limit: 70)
        }
    }
    return nil
}

private func geminiMessageText(from message: JSONObject) -> String? {
    if let content = message.string("content") {
        return content
    }
    let parts = message.array("content") ?? []
    let texts = parts.compactMap { ($0 as? JSONObject)?.string("text") }.filter { $0.isEmpty == false }
    return texts.isEmpty ? nil : texts.joined(separator: "\n")
}

private func geminiProjectRoot(for sessionURL: URL) -> String? {
    let projectRootURL = sessionURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(".project_root")
    guard FileManager.default.fileExists(atPath: projectRootURL.path) else {
        return nil
    }
    return compactWhitespace(try? String(contentsOf: projectRootURL, encoding: .utf8))
}

private func discoverCapturedSessions(for source: AgentSource, in environment: AgentEnvironment) throws -> [DiscoveredSession] {
    let captures = try loadCapturedEvents(for: source, in: environment)
    let grouped = Dictionary(grouping: captures) { captureSessionKey($0) }
    return grouped.compactMap { key, captures in
        guard let key else { return nil }
        let latest = captures.max(by: { $0.timestamp < $1.timestamp })
        let title = compactWhitespace(latest?.title ?? latest?.message ?? latest?.cwd ?? key) ?? key
        return DiscoveredSession(
            source: source,
            sessionId: key,
            title: shortened(title, limit: 70),
            terminalSessionId: latest?.terminalSessionId
        )
    }
    .sorted { lhs, rhs in lhs.title < rhs.title }
}

private func loadCapturedEvents(for source: AgentSource, in environment: AgentEnvironment) throws -> [AgentBridgeCapture] {
    let decoder = FixtureLoader.decoder
    var captures: [AgentBridgeCapture] = []
    for directory in bridgeCaptureDirectories(for: source, in: environment) where FileManager.default.fileExists(atPath: directory.path) {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in urls {
            let content = try String(contentsOf: url, encoding: .utf8)
            for object in splitJSONObjectRecords(from: content) {
                captures.append(try decoder.decode(AgentBridgeCapture.self, from: Data(object.utf8)))
            }
        }
    }
    return captures.sorted { $0.timestamp < $1.timestamp }
}

private func captureSessionKey(_ capture: AgentBridgeCapture) -> String? {
    if let sessionId = compactWhitespace(capture.sessionId), sessionId.isEmpty == false {
        return sessionId
    }
    if let cwd = compactWhitespace(capture.cwd), cwd.isEmpty == false {
        return cwd
    }
    if let title = compactWhitespace(capture.title), title.isEmpty == false {
        return title
    }
    return nil
}

private func splitJSONObjectRecords(from text: String) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return [] }

    var objects: [String] = []
    var current = String()
    var depth = 0
    var insideString = false
    var isEscaping = false

    for character in trimmed {
        current.append(character)

        if insideString {
            if isEscaping {
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else if character == "\"" {
                insideString = false
            }
            continue
        }

        if character == "\"" {
            insideString = true
            continue
        }

        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                let record = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if record.isEmpty == false {
                    objects.append(record)
                }
                current.removeAll(keepingCapacity: true)
            }
        }
    }

    let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if trailing.isEmpty == false {
        objects.append(trailing)
    }

    return objects
}

private func aggregateCapturedSession(session: DiscoveredSession, captures: [AgentBridgeCapture]) -> AgentEvent {
    let latest = captures.max(by: { $0.timestamp < $1.timestamp })!
    let timeline = captures.map { capture in
        AgentTimelineEntry(
            kind: captureTimelineKind(capture.status),
            title: compactWhitespace(capture.message ?? capture.toolName ?? capture.hookName ?? session.title) ?? session.title,
            detail: capture.hookName,
            timestamp: capture.timestamp
        )
    }
    return AgentEvent(
        source: latest.source,
        sessionId: session.sessionId,
        terminalSessionId: latest.terminalSessionId,
        title: session.title,
        status: latest.status,
        lastAssistantMessage: compactWhitespace(latest.message),
        tasks: makeToolTasks(from: timeline, running: latest.status == .runningTool),
        timeline: Array(timeline.suffix(18)),
        workingDirectory: compactWhitespace(latest.cwd),
        timestamp: latest.timestamp
    )
}

private func captureTimelineKind(_ status: AgentStatus) -> AgentTimelineEntryKind {
    switch status {
    case .runningTool:
        .tool
    case .waitingForApproval, .waitingForInput, .complete, .compacting, .error, .interrupted, .idle, .thinking:
        .system
    }
}

private func makeToolTasks(from timeline: [AgentTimelineEntry], running: Bool) -> [AgentTaskSnapshot] {
    let tools = timeline.filter { $0.kind == .tool }
    guard tools.isEmpty == false else { return [] }
    return tools.suffix(4).enumerated().map { index, entry in
        AgentTaskSnapshot(
            id: entry.id.isEmpty ? "task-\(index)" : entry.id,
            title: entry.title,
            isComplete: running ? index < max(tools.suffix(4).count - 1, 0) : true
        )
    }
}

private func firstUserTitle(from timeline: [AgentTimelineEntry]) -> String? {
    timeline.first(where: { $0.kind == .user }).map { shortened($0.title, limit: 70) }
}

private func compactWhitespace(_ text: String?) -> String? {
    guard let text else { return nil }
    let collapsed = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return collapsed.isEmpty ? nil : collapsed
}

private func shortened(_ text: String, limit: Int) -> String {
    guard text.count > limit else { return text }
    return String(text.prefix(limit - 1)) + "…"
}

private func firstLine(of text: String) -> String {
    compactWhitespace(text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init)) ?? text
}

private func fileModificationDate(for url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
}

private func parseDate(_ raw: String?) -> Date? {
    guard let raw else { return nil }
    let withFractionalSeconds = ISO8601DateFormatter()
    withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractionalSeconds.date(from: raw) {
        return date
    }

    let basic = ISO8601DateFormatter()
    basic.formatOptions = [.withInternetDateTime]
    return basic.date(from: raw)
}

private func codexHistoryItems(from lines: [JSONObject]) throws -> [AgentHistoryItem] {
    var items: [AgentHistoryItem] = []
    for line in lines {
        let timestamp = parseDate(line.string("timestamp")) ?? .distantPast
        switch line.string("type") {
        case "event_msg":
            let payload = line.dictionary("payload")
            switch payload?.string("type") {
            case "user_message":
                if let message = compactWhitespace(payload?.string("message")) {
                    items.append(AgentHistoryItem(kind: .user, title: message, timestamp: timestamp))
                }
            case "agent_message":
                if let message = compactWhitespace(payload?.string("message")) {
                    items.append(AgentHistoryItem(kind: .assistant, title: message, timestamp: timestamp))
                }
            default:
                break
            }
        case "response_item":
            let payload = line.dictionary("payload")
            switch payload?.string("type") {
            case "function_call", "custom_tool_call", "web_search_call":
                let name = compactWhitespace(payload?.string("name") ?? payload?.dictionary("action")?.string("type")) ?? "tool"
                items.append(AgentHistoryItem(kind: .tool, title: name, body: payload?.string("arguments"), timestamp: timestamp))
            case "message":
                if payload?.string("role") == "assistant", let text = firstContentText(payload?.array("content")) {
                    items.append(AgentHistoryItem(kind: .assistant, title: compactWhitespace(text) ?? text, timestamp: timestamp))
                }
            default:
                break
            }
        case "compacted":
            items.append(AgentHistoryItem(kind: .system, title: "Session compacted", timestamp: timestamp))
        default:
            break
        }
    }
    return items.suffix(200).map { $0 }
}

private func geminiHistoryItems(from url: URL) throws -> [AgentHistoryItem] {
    let object = try jsonObject(from: Data(contentsOf: url))
    let messages = object.array("messages") ?? []
    return messages.compactMap { raw in
        guard let message = raw as? JSONObject else { return nil }
        let timestamp = parseDate(message.string("timestamp")) ?? fileModificationDate(for: url)
        let text = compactWhitespace(geminiMessageText(from: message))
        switch message.string("type") {
        case "user":
            guard let text else { return nil }
            return AgentHistoryItem(kind: .user, title: text, timestamp: timestamp)
        case "gemini":
            guard let text else { return nil }
            return AgentHistoryItem(kind: .assistant, title: text, timestamp: timestamp)
        default:
            guard let text else { return nil }
            return AgentHistoryItem(kind: .system, title: text, timestamp: timestamp)
        }
    }
}

private func readJSONLines(from url: URL) throws -> [JSONObject] {
    try String(contentsOf: url, encoding: .utf8)
        .split(whereSeparator: \.isNewline)
        .compactMap { line in
            guard line.isEmpty == false else { return nil }
            return try jsonObject(from: Data(line.utf8))
        }
}

private func readCodexRolloutLines(from url: URL) throws -> [JSONObject] {
    let head = try readJSONLineStringsFromHead(of: url, maxByteCount: 128 * 1024, maxLineCount: 80)
    let tail = try readJSONLineStringsFromTail(of: url, maxByteCount: 768 * 1024, maxLineCount: 1600)

    var merged: [String] = []
    var seen = Set<String>()
    for line in head + tail where seen.insert(line).inserted {
        merged.append(line)
    }

    return merged.compactMap { line in
        try? jsonObject(from: Data(line.utf8))
    }
}

private func readJSONLineStringsFromHead(
    of url: URL,
    maxByteCount: Int,
    maxLineCount: Int
) throws -> [String] {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }

    let data = try handle.read(upToCount: maxByteCount) ?? Data()
    guard let string = String(data: data, encoding: .utf8) else { return [] }

    return string
        .split(whereSeparator: \.isNewline)
        .prefix(maxLineCount)
        .map(String.init)
        .filter { !$0.isEmpty }
}

private func readJSONLineStringsFromTail(
    of url: URL,
    maxByteCount: Int,
    maxLineCount: Int
) throws -> [String] {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }

    let fileSize = try handle.seekToEnd()
    let offset = fileSize > UInt64(maxByteCount) ? fileSize - UInt64(maxByteCount) : 0
    try handle.seek(toOffset: offset)
    let data = try handle.readToEnd() ?? Data()
    guard let string = String(data: data, encoding: .utf8) else { return [] }

    var lines = string
        .split(whereSeparator: \.isNewline)
        .map(String.init)
        .filter { !$0.isEmpty }

    if offset > 0, lines.isEmpty == false {
        lines.removeFirst()
    }

    return Array(lines.suffix(maxLineCount))
}

private func jsonObject(from data: Data) throws -> JSONObject {
    guard let object = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
        throw NSError(domain: "AgentIsland.SourceAdapters", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Expected a JSON object."
        ])
    }
    return object
}

private func jsonArray(from data: Data) throws -> [JSONObject] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [JSONObject] else {
        throw NSError(domain: "AgentIsland.SourceAdapters", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Expected a JSON array."
        ])
    }
    return object
}

private func jsonArrayOfStrings(from text: String?) throws -> [String] {
    guard let text, let data = text.data(using: .utf8) else { return [] }
    guard let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
        return []
    }
    return array
}

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? {
        self[key] as? String
    }

    func dictionary(_ key: String) -> JSONObject? {
        self[key] as? JSONObject
    }

    func array(_ key: String) -> [Any]? {
        self[key] as? [Any]
    }

    func int(_ key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        if let value = self[key] as? String {
            return Int(value)
        }
        return nil
    }
}

private func sqliteJSONRows(databaseURL: URL, query: String) throws -> [JSONObject] {
    guard FileManager.default.fileExists(atPath: databaseURL.path) else { return [] }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = ["-json", databaseURL.path, query]
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()

    let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    if process.terminationStatus != 0 {
        let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "sqlite3 failed"
        throw NSError(domain: "AgentIsland.SourceAdapters", code: Int(process.terminationStatus), userInfo: [
            NSLocalizedDescriptionKey: errorText.trimmingCharacters(in: .whitespacesAndNewlines)
        ])
    }

    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return [] }
    return try jsonArray(from: Data(trimmed.utf8))
}

private func sqliteQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "''"))'"
}

private func sqliteTimestamp(_ value: Int?) -> Date {
    guard let value else { return Date() }
    if value > 1_000_000_000_000 {
        return Date(timeIntervalSince1970: TimeInterval(value) / 1_000)
    }
    return Date(timeIntervalSince1970: TimeInterval(value))
}

private func openClawDatabaseURL(in environment: AgentEnvironment) -> URL {
    environment.homeDirectory.appendingPathComponent(".local/share/opencode/opencode.db")
}

private func openClawPluginURL(in environment: AgentEnvironment) -> URL {
    environment.homeDirectory.appendingPathComponent(".config/opencode/plugins/agent-island.js")
}

private func prefixedOpenClawSessionID(_ rawSessionID: String) -> String {
    rawSessionID.hasPrefix("opencode-") ? rawSessionID : "opencode-\(rawSessionID)"
}

private func rawOpenClawSessionID(from sessionID: String) -> String {
    sessionID.replacingOccurrences(of: "opencode-", with: "")
}

private func firstContentText(_ content: [Any]?) -> String? {
    guard let content else { return nil }
    let texts = content.compactMap { ($0 as? JSONObject)?.string("text") }
    return texts.isEmpty ? nil : texts.joined(separator: "\n")
}

private func isFixtureSession(_ session: DiscoveredSession, fixtureRoot: URL) -> Bool {
    guard let path = session.fileURL?.path else { return false }
    return path.hasPrefix(fixtureRoot.path)
}

private func bridgeCaptureDirectory(for source: AgentSource, in environment: AgentEnvironment) -> URL {
    environment.homeDirectory
        .appendingPathComponent(".agent-island", isDirectory: true)
        .appendingPathComponent("events", isDirectory: true)
        .appendingPathComponent(source.rawValue, isDirectory: true)
}

private func legacyBridgeCaptureDirectory(for source: AgentSource, in environment: AgentEnvironment) -> URL {
    environment.homeDirectory
        .appendingPathComponent(".vibe-island", isDirectory: true)
        .appendingPathComponent("events", isDirectory: true)
        .appendingPathComponent(source.rawValue, isDirectory: true)
}

private func bridgeCaptureDirectories(for source: AgentSource, in environment: AgentEnvironment) -> [URL] {
    [bridgeCaptureDirectory(for: source, in: environment), legacyBridgeCaptureDirectory(for: source, in: environment)]
}

private func ensureBridgeLauncher(in environment: AgentEnvironment) throws -> URL {
    let binDirectory = environment.homeDirectory
        .appendingPathComponent(".agent-island", isDirectory: true)
        .appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)
    let launcherURL = binDirectory.appendingPathComponent("agent-island-bridge")
    let workspace = environment.workingDirectory.path
    let script = """
#!/bin/zsh
set -e
for B in "\(workspace)/dist/Agent Island.app/Contents/Helpers/agent-island-bridge" "\(workspace)/.build/debug/agent-island-bridge" "\(workspace)/.build/release/agent-island-bridge"; do
  if [ -x "$B" ]; then
    exec "$B" "$@"
  fi
done
H=/Contents/Helpers/agent-island-bridge
for P in "/Applications/Agent Island.app" "$HOME/Applications/Agent Island.app" "/Applications/agent-island.app"; do
  B="${P}${H}"
  if [ -x "$B" ]; then
    exec "$B" "$@"
  fi
done
echo "agent-island-bridge: helper not found. Build or install Agent Island first." >&2
exit 127
"""
    let existing = try? String(contentsOf: launcherURL, encoding: .utf8)
    if existing != script {
        try script.write(to: launcherURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcherURL.path)
    }
    let legacyLauncherURL = binDirectory.appendingPathComponent("vibe-island-bridge")
    if (try? String(contentsOf: legacyLauncherURL, encoding: .utf8)) != script {
        try script.write(to: legacyLauncherURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: legacyLauncherURL.path)
    }
    return launcherURL
}

private func ensureClaudeSocketClient(in environment: AgentEnvironment) throws -> URL {
    let binDirectory = environment.homeDirectory
        .appendingPathComponent(".agent-island", isDirectory: true)
        .appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)

    let scriptURL = binDirectory.appendingPathComponent("agent-island-claude-hook.py")
    let script = """
#!/usr/bin/env python3
import json
import os
import socket
import subprocess
import sys

SOCKET_PATH = "/tmp/agent-island.sock"
TIMEOUT_SECONDS = 300

def get_tty():
    parent_pid = os.getppid()
    try:
        result = subprocess.run(
            ["ps", "-p", str(parent_pid), "-o", "tty="],
            capture_output=True,
            text=True,
            timeout=2
        )
        tty = result.stdout.strip()
        if tty and tty != "??" and tty != "-":
            if not tty.startswith("/dev/"):
                tty = "/dev/" + tty
            return tty
    except Exception:
        pass
    return None

def send_event(state):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(TIMEOUT_SECONDS)
    sock.connect(SOCKET_PATH)
    sock.sendall(json.dumps(state).encode())
    if state.get("status") == "waiting_for_approval":
        response = sock.recv(4096)
        sock.close()
        if response:
            return json.loads(response.decode())
    else:
        sock.close()
    return None

def main():
    data = json.load(sys.stdin)
    event = {
        "session_id": data.get("session_id", "unknown"),
        "cwd": data.get("cwd", ""),
        "event": data.get("hook_event_name", ""),
        "status": "processing",
        "pid": os.getppid(),
        "tty": get_tty(),
        "tool": data.get("tool_name"),
        "tool_use_id": data.get("tool_use_id"),
        "message": data.get("message"),
    }

    hook_name = event["event"]
    if hook_name == "PermissionRequest":
        event["status"] = "waiting_for_approval"
        response = send_event(event)
        if response:
            decision = response.get("decision", "ask")
            reason = response.get("reason", "")
            if decision == "allow":
                print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}))
                return
            if decision == "deny":
                print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "deny", "message": reason or "Denied by user via Agent Island"}}}))
                return
        return
    elif hook_name == "Notification":
        event["status"] = "waiting_for_input"
    elif hook_name == "PostToolUse":
        event["status"] = "processing"
    elif hook_name == "PreToolUse":
        event["status"] = "running_tool"
    elif hook_name == "Stop" or hook_name == "SessionStart" or hook_name == "SubagentStop":
        event["status"] = "waiting_for_input"
    elif hook_name == "SessionEnd":
        event["status"] = "ended"
    elif hook_name == "PreCompact":
        event["status"] = "compacting"

    try:
        send_event(event)
    except Exception:
        pass

if __name__ == "__main__":
    main()
"""

    let existing = try? String(contentsOf: scriptURL, encoding: .utf8)
    if existing != script {
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }
    let legacyScriptURL = binDirectory.appendingPathComponent("vibe-island-claude-hook.py")
    if (try? String(contentsOf: legacyScriptURL, encoding: .utf8)) != script {
        try script.write(to: legacyScriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: legacyScriptURL.path)
    }
    return scriptURL
}

private func detectPython() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["python3"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            return "python3"
        }
    } catch {}
    return "python"
}

private func codexHooksURL(in environment: AgentEnvironment) -> URL {
    environment.homeDirectory.appendingPathComponent(".codex/hooks.json")
}

private func codexConfigURL(in environment: AgentEnvironment) -> URL {
    environment.homeDirectory.appendingPathComponent(".codex/config.toml")
}

private func geminiSettingsURL(in environment: AgentEnvironment) -> URL {
    environment.homeDirectory.appendingPathComponent(".gemini/settings.json")
}

private func claudeSettingsURL(in environment: AgentEnvironment) -> URL {
    environment.homeDirectory.appendingPathComponent(".claude/settings.json")
}

private func hookCommandExists(at url: URL, command: String) -> Bool {
    guard
        FileManager.default.fileExists(atPath: url.path),
        let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data)
    else {
        return false
    }
    return collectCommandStrings(in: object).contains(command)
}

private func codexHooksEnabled(at url: URL) -> Bool {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        return false
    }
    return text.contains("codex_hooks = true")
}

private func claudeHookStateMatches(at url: URL, command: String) -> Bool {
    hookCommandExists(at: url, command: command)
}

private func collectCommandStrings(in value: Any) -> [String] {
    if let dict = value as? JSONObject {
        var commands: [String] = []
        for (key, nested) in dict {
            if key == "command", let command = nested as? String {
                commands.append(command)
            } else {
                commands.append(contentsOf: collectCommandStrings(in: nested))
            }
        }
        return commands
    }
    if let array = value as? [Any] {
        return array.flatMap(collectCommandStrings(in:))
    }
    return []
}

private func ensureCodexHooks(at url: URL, command: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    var root = (try? readJSONObject(at: url)) ?? [:]
    var hooks = root["hooks"] as? JSONObject ?? [:]
    let hookPayload: [Any] = [[
        "hooks": [[
            "command": command,
            "timeout": 5,
            "type": "command",
        ]]
    ]]
    for key in ["SessionStart", "Stop", "UserPromptSubmit"] {
        hooks[key] = hookPayload
    }
    root["hooks"] = hooks
    try writeJSONObject(root, to: url)
}

private func removeCodexHooks(at url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    var root = try readJSONObject(at: url)
    guard var hooks = root["hooks"] as? JSONObject else { return }
    for key in ["SessionStart", "Stop", "UserPromptSubmit"] {
        hooks.removeValue(forKey: key)
    }
    if hooks.isEmpty {
        root.removeValue(forKey: "hooks")
    } else {
        root["hooks"] = hooks
    }
    try writeJSONObject(root, to: url)
}

private func removeCodexConfig(at url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    let lines = try String(contentsOf: url, encoding: .utf8)
        .components(separatedBy: .newlines)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("codex_hooks") }
    let text = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    try (text.isEmpty ? "" : text + "\n").write(to: url, atomically: true, encoding: .utf8)
}

private func ensureCodexConfig(at url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    var lines = (try? String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)) ?? []
    if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("codex_hooks") }) {
        lines[index] = "codex_hooks = true"
    } else {
        if lines.last?.isEmpty == false {
            lines.append("")
        }
        lines.append("codex_hooks = true")
    }
    let text = lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private func ensureGeminiHooks(at url: URL, command: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    var root = (try? readJSONObject(at: url)) ?? [:]
    var hooks = root["hooks"] as? JSONObject ?? [:]
    let hookPayload: [Any] = [[
        "hooks": [[
            "command": command,
            "timeout": 5000,
            "type": "command",
        ]]
    ]]
    for key in ["AfterAgent", "AfterTool", "BeforeAgent", "BeforeTool", "SessionEnd", "SessionStart"] {
        hooks[key] = hookPayload
    }
    root["hooks"] = hooks
    try writeJSONObject(root, to: url)
}

private func removeGeminiHooks(at url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    var root = try readJSONObject(at: url)
    guard var hooks = root["hooks"] as? JSONObject else { return }
    for key in ["AfterAgent", "AfterTool", "BeforeAgent", "BeforeTool", "SessionEnd", "SessionStart"] {
        hooks.removeValue(forKey: key)
    }
    if hooks.isEmpty {
        root.removeValue(forKey: "hooks")
    } else {
        root["hooks"] = hooks
    }
    try writeJSONObject(root, to: url)
}

private func ensureClaudeHooks(at url: URL, command: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    var root = (try? readJSONObject(at: url)) ?? [:]
    var hooks = root["hooks"] as? JSONObject ?? [:]

    hooks["Notification"] = [[
        "matcher": "*",
        "hooks": [[
            "command": command,
            "type": "command",
        ]]
    ]]
    hooks["PermissionRequest"] = [[
        "matcher": "*",
        "hooks": [[
            "command": command,
            "timeout": 86400,
            "type": "command",
        ]]
    ]]
    hooks["PostToolUse"] = [[
        "matcher": "*",
        "hooks": [[
            "command": command,
            "type": "command",
        ]]
    ]]
    hooks["PreCompact"] = [[
        "hooks": [[
            "command": command,
            "type": "command",
        ]]
    ]]
    hooks["PreToolUse"] = [[
        "matcher": "*",
        "hooks": [[
            "command": command,
            "type": "command",
        ]]
    ]]
    for key in ["SessionEnd", "SessionStart", "Stop", "SubagentStart", "SubagentStop", "UserPromptSubmit"] {
        hooks[key] = [[
            "hooks": [[
                "command": command,
                "type": "command",
            ]]
        ]]
    }

    root["hooks"] = hooks
    try writeJSONObject(root, to: url)
}

private func removeClaudeHooks(at url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    var root = try readJSONObject(at: url)
    guard var hooks = root["hooks"] as? JSONObject else { return }
    for key in ["Notification", "PermissionRequest", "PostToolUse", "PreCompact", "PreToolUse", "SessionEnd", "SessionStart", "Stop", "SubagentStart", "SubagentStop", "UserPromptSubmit"] {
        hooks.removeValue(forKey: key)
    }
    if hooks.isEmpty {
        root.removeValue(forKey: "hooks")
    } else {
        root["hooks"] = hooks
    }
    try writeJSONObject(root, to: url)
}

private func readJSONObject(at url: URL) throws -> JSONObject {
    try jsonObject(from: Data(contentsOf: url))
}

private func writeJSONObject(_ object: JSONObject, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
}

private func shellEscape(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

private func runDetached(_ command: [String], workingDirectory: String?) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = command
    if let workingDirectory, workingDirectory.isEmpty == false {
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
    }
    let nullHandle = FileHandle(forWritingAtPath: "/dev/null")
    process.standardOutput = nullHandle
    process.standardError = nullHandle
    process.standardInput = nil
    try process.run()
}

private func shellCommand(executable: String, arguments: [String], workingDirectory: String?) -> String {
    let executablePart = ([executable] + arguments).map(shellEscape).joined(separator: " ")
    guard let workingDirectory, workingDirectory.isEmpty == false else {
        return executablePart
    }
    return "cd \(shellEscape(workingDirectory)) && \(executablePart)"
}
