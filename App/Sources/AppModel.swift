import AgentCore
import AppKit
import IDEBridge
import Localization
import SoundKit
import SourceAdapters
import SwiftUI
import Telemetry
import TerminalAdapters
import UpdateKit

public enum DashboardMode: String, CaseIterable, Identifiable, Sendable {
    case monitor, approve, ask, jump
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbolName: String {
        switch self {
        case .monitor: return "square.grid.2x2.fill"
        case .approve: return "shield.fill"
        case .ask: return "ellipsis.message.fill"
        case .jump: return "arrow.turn.up.right"
        }
    }
    public var accentColor: Color {
        switch self {
        case .monitor: return .green
        case .approve: return .orange
        case .ask: return .cyan
        case .jump: return .blue
        }
    }
}

public enum LayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case clean, detailed
    public var id: String { rawValue }
}

public enum DisplayTarget: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic, builtIn, main
    public var id: String { rawValue }
}

public enum UsageValueMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case used, remaining
    public var id: String { rawValue }
}

public struct AdapterSetupState: Identifiable, Sendable, Hashable {
    public let source: AgentSource
    public let status: HookInstallationStatus
    public let message: String
    public let touchedPaths: [String]
    public var id: String { source.rawValue }
}

public struct SourceSelectionState: Identifiable, Sendable, Hashable {
    public let source: AgentSource
    public let isDetected: Bool
    public let isEnabled: Bool
    public let detail: String
    public let touchedPaths: [String]
    public let recentSessionCount: Int
    public let recentSessionTitles: [String]
    public let isInstalledOnHost: Bool
    public let isProcessRunning: Bool
    public let containerMatchCount: Int
    public let containerMatches: [String]

    public var id: String { source.rawValue }
}

public struct RuntimeDetectionState: Sendable, Hashable {
    public let dockerAvailable: Bool
    public let dockerMessage: String

    public init(dockerAvailable: Bool, dockerMessage: String) {
        self.dockerAvailable = dockerAvailable
        self.dockerMessage = dockerMessage
    }
}

public enum DirectSubmissionPlan: Sendable, Hashable {
    case detachedCLI(executable: String, arguments: [String], workingDirectory: String?)
    case terminalCommand(String)
}

public enum UpdatePresentation: Sendable, Hashable {
    case idle, checking, available(String), upToDate(String), failed(String)
}

private struct ReloadResult: Sendable {
    let events: [AgentEvent]
    let setupStates: [AdapterSetupState]
    let failures: [String]
}

private struct DockerContainerMatch: Sendable, Hashable {
    let name: String
    let image: String
    let status: String
}

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var sessions: [AgentSession] = []
    @Published public var selectedSessionID: String?
    @Published public var locale: AppLocale = .automatic
    @Published public var soundSettings = SoundSettings() {
        didSet {
            guard soundSettingsReady else { return }
            let normalized = SoundPackCatalog.normalizedSelection(soundSettings.selectedSoundPackID, availablePacks: soundPacks)
            if normalized != soundSettings.selectedSoundPackID {
                soundSettings.selectedSoundPackID = normalized
                return
            }
            soundEngine.update(settings: soundSettings)
            persistSoundSettings()
        }
    }
    @Published public var smartSuppressionEnabled = true
    @Published public var showCompletedTasks = true
    @Published public var diagnosticsMessage: String?
    @Published public var dashboardMode: DashboardMode = .monitor
    @Published public var launchAtLoginEnabled = false
    @Published public var autoHideWhenIdle = false
    @Published public var autoCollapseOnLeave = true
    @Published public var hideInFullscreen = true
    @Published public var showUsage = true
    @Published public var showAgentDetail = true
    @Published public var layoutMode: LayoutMode = .clean
    @Published public var displayTarget: DisplayTarget = .automatic
    @Published public var islandExpanded = false
    @Published public var contentFontSize: Double = 11
    @Published public var completionHeight: Double = 90
    @Published public var maxPanelHeight: Double = 560
    @Published public var usageValueMode: UsageValueMode = .used
    @Published public var autoDetectProbeSessions = true
    @Published public var showOnboarding = false
    @Published public private(set) var soundPacks: [SoundPack] = []
    @Published public private(set) var adapterSetupStates: [AdapterSetupState] = []
    @Published public private(set) var sourceSelectionStates: [SourceSelectionState] = []
    @Published public private(set) var sessionHistories: [String: [AgentHistoryItem]] = [:]
    @Published public private(set) var runtimeDetectionState = RuntimeDetectionState(
        dockerAvailable: false,
        dockerMessage: "Docker daemon is not available."
    )
    @Published public private(set) var updatePresentation: UpdatePresentation = .idle
    @Published public private(set) var latestReleaseName: String?

    private let sessionIndexStore = SessionIndexStore()
    private let adapters: [any AgentSourceAdapter]
    private let sessionCoordinator: SessionCoordinator
    private let terminalRegistry: TerminalAdapterRegistry
    private let updateService = UpdateService()
    private let telemetryClient: any TelemetryClient
    private let soundEngine: SoundEngine
    private let defaults: UserDefaults
    private var hasPerformedInitialLoad = false
    private var enabledSources: Set<AgentSource>
    private let enabledSourcesDefaultsKey = "app.agentisland.enabled-sources"
    private let legacyEnabledSourcesDefaultsKey = "app.vibeisland.enabled-sources"
    private let soundSettingsDefaultsKey = "app.agentisland.sound-settings"
    private let legacySoundSettingsDefaultsKey = "app.vibeisland.sound-settings"
    private let onboardingSeenDefaultsKey = "app.agentisland.onboarding.seen"
    private let legacyOnboardingSeenDefaultsKey = "app.vibeisland.onboarding.seen"
    private var hasSavedEnabledSourcesSelection: Bool
    private var soundSettingsReady = false

    public init(
        sessions: [AgentSession] = [],
        adapters: [any AgentSourceAdapter] = AgentSourceAdapterFactory.production(),
        terminalRegistry: TerminalAdapterRegistry = .live(),
        telemetryClient: any TelemetryClient = NoOpTelemetryClient(),
        defaults: UserDefaults = .standard
    ) {
        self.sessions = sessions
        self.selectedSessionID = sessions.first?.id
        self.adapters = adapters
        self.sessionCoordinator = SessionCoordinator(adapters: adapters, sessionIndexStore: sessionIndexStore)
        self.terminalRegistry = terminalRegistry
        self.telemetryClient = telemetryClient
        self.defaults = defaults
        self.hasSavedEnabledSourcesSelection =
            defaults.object(forKey: enabledSourcesDefaultsKey) != nil ||
            defaults.object(forKey: legacyEnabledSourcesDefaultsKey) != nil
        _ = try? SoundPackCatalog.ensurePacksDirectory(homeDirectory: Self.defaultsHomeDirectory(defaults: defaults))
        let loadedSoundSettings = Self.loadSoundSettings(from: defaults)
        let availableSoundPacks = SoundPackCatalog.availablePacks(homeDirectory: Self.defaultsHomeDirectory(defaults: defaults))
        let normalizedPackID = SoundPackCatalog.normalizedSelection(loadedSoundSettings.selectedSoundPackID, availablePacks: availableSoundPacks)
        let settings = SoundSettings(
            isEnabled: loadedSoundSettings.isEnabled,
            volume: loadedSoundSettings.volume,
            selectedSoundPackID: normalizedPackID
        )
        self.soundSettings = settings
        self.soundPacks = availableSoundPacks
        self.soundEngine = SoundEngine(settings: settings)
        let savedSources = (
            defaults.array(forKey: enabledSourcesDefaultsKey) as? [String]
            ?? defaults.array(forKey: legacyEnabledSourcesDefaultsKey) as? [String]
            ?? []
        )
            .compactMap(AgentSource.init(rawValue:))
        self.enabledSources = Set(savedSources)
        let seen = defaults.object(forKey: onboardingSeenDefaultsKey) as? Bool
            ?? defaults.object(forKey: legacyOnboardingSeenDefaultsKey) as? Bool
            ?? false
        self.showOnboarding = !seen
        self.islandExpanded = !seen
        self.soundSettingsReady = true
    }

    public var selectedSession: AgentSession? {
        let filtered = filteredSessions
        guard let id = selectedSessionID else { return filtered.first ?? sessions.first }
        return filtered.first { $0.id == id } ?? filtered.first
    }

    // --- Aliases for UI views ---
    public var monitoredSessions: [AgentSession] {
        autoDetectProbeSessions ? sessions.filter { !isProbeSession($0) } : sessions
    }
    public var primarySession: AgentSession? { selectedSession ?? monitoredSessions.first ?? sessions.first }
    public var attentionSessions: [AgentSession] { monitoredSessions.filter(\.needsAttention) }
    public var islandSessionCountText: String { attentionSessions.isEmpty ? "\(monitoredSessions.count)" : "\(attentionSessions.count)" }
    public var menuBarTitle: String { attentionSessions.isEmpty ? "Agent Island" : "Agent Island \(attentionSessions.count)" }
    public var statusLine: String { selectedSession?.title ?? "Agent Island" }
    public var currentUsageValue: String? {
        guard showUsage, let usage = selectedSession?.usage, let total = usage.totalTokens else { return nil }
        switch usageValueMode {
        case .used:
            return "\(total) tok used"
        case .remaining:
            return "\(max(2_000_000_000 - total, 0)) tok left"
        }
    }
    public var currentAppVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0-oss"
    }

    public func sessions(for mode: DashboardMode) -> [AgentSession] {
        let base = monitoredSessions
        switch mode {
        case .monitor: return base
        case .approve: return base.filter { $0.approvalPayload != nil || $0.status == .waitingForApproval }
        case .ask: return base.filter { $0.questionPayload != nil || $0.status == .waitingForInput }
        case .jump: return base.filter { $0.terminalSessionId != nil || $0.originPath != nil || $0.workingDirectory != nil || $0.resumeCommand != nil }
        }
    }

    public var filteredSessions: [AgentSession] { sessions(for: dashboardMode) }

    public var enabledSourceIDs: Set<String> {
        Set(enabledSources.map(\.rawValue))
    }

    public var productSourceSelectionStates: [SourceSelectionState] {
        sourceSelectionStates.filter { $0.source.isFirstClassSupported }
    }

    public var selectedSoundPack: SoundPack? {
        soundPacks.first { $0.id == soundSettings.selectedSoundPackID }
    }

    public func activeAdapters() -> [any AgentSourceAdapter] {
        adapters.filter { enabledSources.contains($0.source) }
    }

    public var selectedSessionHistory: [AgentHistoryItem] {
        guard let selectedSession else { return [] }
        return sessionHistories[selectedSession.id] ?? []
    }

    public var emptyStateMessage: String {
        let detected = sourceSelectionStates.filter(\.isDetected).map(\.source.displayName)
        if detected.isEmpty {
            return runtimeDetectionState.dockerMessage
        }
        return "Detected on this Mac: \(detected.joined(separator: ", ")). No live sessions are currently active. \(runtimeDetectionState.dockerMessage)"
    }

    public func capabilities(for source: AgentSource) -> AgentSourceCapabilities? {
        sourceAdapter(for: source)?.capabilities
    }

    public func performInitialLoad(environment: AgentEnvironment = .live()) async {
        guard !hasPerformedInitialLoad else { return }
        hasPerformedInitialLoad = true
        await refreshSourceSelectionStates(environment: environment)
        if hasSavedEnabledSourcesSelection == false {
            enableAllDetectedSources(environment: environment, triggerReload: false)
            hasSavedEnabledSourcesSelection = true
        }
        await refreshAdapterSetupStates(environment: environment)
        let update = await sessionCoordinator.start(
            enabledSources: enabledSources,
            environment: environment
        ) { [weak self] update in
            Task { @MainActor in
                self?.applyCoordinatorUpdate(update)
            }
        }
        applyCoordinatorUpdate(update)
    }

    public func reloadLiveData(environment: AgentEnvironment = .live()) async {
        await refreshSourceSelectionStates(environment: environment)
        await refreshAdapterSetupStates(environment: environment)
        let update = await sessionCoordinator.updateEnabledSources(enabledSources, environment: environment)
        applyCoordinatorUpdate(update)
    }

    public func select(_ session: AgentSession) {
        selectedSessionID = session.id
        islandExpanded = true
        Task {
            await refreshHistory(for: session)
        }
    }

    public func setDashboardMode(_ mode: DashboardMode) {
        dashboardMode = mode
        islandExpanded = true
        if filteredSessions.contains(where: { $0.id == selectedSessionID }) == false {
            selectedSessionID = filteredSessions.first?.id
        }
        Task {
            await refreshSelectedHistory()
        }
    }

    public func expandIsland() { islandExpanded = true }
    public func collapseIsland() { islandExpanded = false }
    public func toggleIsland() { islandExpanded.toggle() }

    public func jumpToSelectedSession() {
        guard let session = selectedSession else { return }
        Task {
            if let adapter = sourceAdapter(for: session.source),
               let target = try? await adapter.resolveJumpTarget(for: session, in: .live()),
               handleResolvedJumpTarget(target, session: session) {
                return
            }
            if let fallbackTarget = fallbackJumpTarget(for: session) {
                _ = handleResolvedJumpTarget(fallbackTarget, session: session)
            }
        }
    }

    public func approveSelectedSession() {
        guard let choice = approvalChoice(matching: ["allow", "approve", "yes"], fallback: .first) else { return }
        Task { await submitSelectedText(choice) }
    }

    public func denySelectedSession() {
        guard let choice = approvalChoice(matching: ["deny", "reject", "no", "cancel"], fallback: .last) else { return }
        Task { await submitSelectedText(choice) }
    }

    public func bypassSelectedSession() {
        if let choice = approvalChoice(matching: ["always", "bypass", "skip"], fallback: .none) {
            Task { await submitSelectedText(choice) }
            return
        }
        if selectedSession?.resumeCommand != nil {
            copyResumeCommand()
            return
        }
        openSelectedWorkingDirectory()
    }

    public func answerSelectedQuestion(option: AgentQuestionOption) {
        Task { await submitSelectedText(option.title) }
    }
    public func submitSelectedResponse(_ response: String) {
        Task { await submitSelectedText(response) }
    }
    public func resumeSelectedSession() {
        guard let command = selectedSession?.resumeCommand else { return }
        do {
            try openCommandInTerminal(command)
            diagnosticsMessage = "Opened a terminal to resume the selected session."
            soundEngine.play(.taskAcknowledge)
        } catch {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            diagnosticsMessage = "Could not launch Terminal automatically. Copied the resume command instead."
        }
    }
    public func copyApprovalChoice(_ choice: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(choice, forType: .string)
        diagnosticsMessage = "Copied '\(choice)' so you can answer the approval prompt in the source CLI."
        soundEngine.play(.taskAcknowledge)
    }
    public func visibleTasks(for session: AgentSession) -> [AgentTaskSnapshot] {
        showCompletedTasks ? session.tasks : session.tasks.filter { !$0.isComplete }
    }
    public func dismissOnboarding() { defaults.set(true, forKey: onboardingSeenDefaultsKey); showOnboarding = false; islandExpanded = !attentionSessions.isEmpty }
    public func showOnboardingFlow() { showOnboarding = true; islandExpanded = true }
    public func terminalLabel(for s: AgentSession) -> String {
        guard let terminalSessionID = s.terminalSessionId else { return "Terminal" }
        switch TerminalKind.inferred(from: terminalSessionID) {
        case .iterm: return "iTerm2"
        case .terminal: return "Terminal"
        case .warp: return "Warp"
        case .cursor: return "Cursor"
        case .vscode: return "VS Code"
        case .tmux: return "tmux"
        case .unknown: return "Terminal"
        }
    }
    public func openLatestRelease() { _ = updateService.openLatestReleasePage() }
    public func openRepository() { _ = updateService.openRepositoryPage() }
    public func openIssueTracker() { _ = updateService.openIssuesPage() }
    public func previewSound(_ c: SoundCategory) { soundEngine.play(c) }
    public func refreshSoundPacks() {
        soundPacks = SoundPackCatalog.availablePacks(homeDirectory: Self.defaultsHomeDirectory(defaults: defaults))
        let normalized = SoundPackCatalog.normalizedSelection(soundSettings.selectedSoundPackID, availablePacks: soundPacks)
        if normalized != soundSettings.selectedSoundPackID {
            soundSettings.selectedSoundPackID = normalized
        } else {
            soundEngine.update(settings: soundSettings)
            persistSoundSettings()
        }
    }
    public func selectSoundPack(_ packID: String) {
        soundSettings = SoundSettings(
            isEnabled: soundSettings.isEnabled,
            volume: soundSettings.volume,
            selectedSoundPackID: packID
        )
        diagnosticsMessage = "Selected \(selectedSoundPack?.displayName ?? "sound pack")."
    }
    public func restoreDefaultSoundPack() {
        selectSoundPack(SoundPackCatalog.defaultPackID)
        diagnosticsMessage = "Restored the default 8-bit sound pack."
    }
    public func openSoundPacksFolder() {
        do {
            let url = try SoundPackCatalog.ensurePacksDirectory(homeDirectory: Self.defaultsHomeDirectory(defaults: defaults))
            NSWorkspace.shared.open(url)
            diagnosticsMessage = "Opened the SoundPacks folder."
        } catch {
            diagnosticsMessage = "Could not open the SoundPacks folder: \(error.localizedDescription)"
        }
    }
    public func importSoundPack() {
        let panel = NSOpenPanel()
        panel.title = "Import Sound Pack"
        panel.prompt = "Import"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }
        do {
            let pack = try SoundPackCatalog.importPack(from: sourceURL, homeDirectory: Self.defaultsHomeDirectory(defaults: defaults))
            refreshSoundPacks()
            selectSoundPack(pack.id)
            diagnosticsMessage = "Imported sound pack '\(pack.displayName)'."
        } catch {
            diagnosticsMessage = "Could not import sound pack: \(error.localizedDescription)"
        }
    }
    public func openSelectedSessionLog() {
        guard let path = selectedSession?.originPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
        diagnosticsMessage = "Opened the selected session log."
    }
    public func revealSelectedSessionLog() {
        guard let path = selectedSession?.originPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        diagnosticsMessage = "Revealed the selected session log."
    }
    public func openSelectedWorkingDirectory() {
        guard let path = selectedSession?.workingDirectory else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
        diagnosticsMessage = "Opened the selected working directory."
    }
    public func copyResumeCommand() {
        guard let command = selectedSession?.resumeCommand else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        diagnosticsMessage = "Copied the resume command."
    }
    public func exportDiagnostics(environment: AgentEnvironment = .live()) async {
        do {
            let url = try DiagnosticsExporter.export(
                sessions: sessions,
                setupStates: adapterSetupStates,
                terminalCapabilities: terminalRegistry.capabilityReport(),
                environment: environment,
                settings: DiagnosticsSettingsSnapshot(
                    dashboardMode: dashboardMode.rawValue,
                    layoutMode: layoutMode.rawValue,
                    displayTarget: displayTarget.rawValue,
                    showUsage: showUsage,
                    smartSuppressionEnabled: smartSuppressionEnabled,
                    showAgentDetail: showAgentDetail
                )
            )
            diagnosticsMessage = "Diagnostics exported to \(url.path)"
        } catch {
            diagnosticsMessage = "Failed to export diagnostics: \(error.localizedDescription)"
        }
    }
    public func checkForUpdates() async {
        updatePresentation = .checking
        do {
            let release = try await updateService.fetchLatestRelease()
            latestReleaseName = release.name
            if release.tagName == "manual-web" {
                updatePresentation = .upToDate("Manual web updates")
            } else {
                updatePresentation = .available(release.name)
            }
            diagnosticsMessage = release.name
        } catch {
            updatePresentation = .failed(error.localizedDescription)
            diagnosticsMessage = "Update check failed: \(error.localizedDescription)"
        }
    }
    public func refreshAdapterSetupStates(environment: AgentEnvironment = .live()) async {
        adapterSetupStates = await collectSetupStates(environment: environment)
    }

    public func refreshSourceSelectionStates(environment: AgentEnvironment = .live()) async {
        let enabledSources = self.enabledSources
        let adapters = self.adapters
        let result = await Task.detached(priority: .utility) {
            await detectSelectableSources(environment: environment, enabledSources: enabledSources, adapters: adapters)
        }.value
        sourceSelectionStates = result.states
        runtimeDetectionState = result.runtime
    }

    public func setSourceEnabled(_ source: AgentSource, isEnabled: Bool, environment: AgentEnvironment = .live()) {
        if isEnabled {
            enabledSources.insert(source)
        } else {
            enabledSources.remove(source)
        }

        defaults.set(enabledSources.map(\.rawValue).sorted(), forKey: enabledSourcesDefaultsKey)
        hasSavedEnabledSourcesSelection = true
        sourceSelectionStates = sourceSelectionStates.map { state in
            guard state.source == source else { return state }
            return SourceSelectionState(
                source: state.source,
                isDetected: state.isDetected,
                isEnabled: isEnabled,
                detail: state.detail,
                touchedPaths: state.touchedPaths,
                recentSessionCount: state.recentSessionCount,
                recentSessionTitles: state.recentSessionTitles,
                isInstalledOnHost: state.isInstalledOnHost,
                isProcessRunning: state.isProcessRunning,
                containerMatchCount: state.containerMatchCount,
                containerMatches: state.containerMatches
            )
        }
        Task {
            let update = await sessionCoordinator.updateEnabledSources(enabledSources, environment: environment)
            await MainActor.run {
                self.applyCoordinatorUpdate(update)
            }
        }
    }

    public func enableAllDetectedSources(environment: AgentEnvironment = .live(), triggerReload: Bool = true) {
        let detectedSources = sourceSelectionStates
            .filter { $0.isDetected && $0.source.isFirstClassSupported }
            .map(\.source)
        enabledSources.formUnion(detectedSources)
        defaults.set(enabledSources.map(\.rawValue).sorted(), forKey: enabledSourcesDefaultsKey)
        hasSavedEnabledSourcesSelection = true
        sourceSelectionStates = sourceSelectionStates.map { state in
            SourceSelectionState(
                source: state.source,
                isDetected: state.isDetected,
                isEnabled: state.isDetected ? true : state.isEnabled,
                detail: state.detail,
                touchedPaths: state.touchedPaths,
                recentSessionCount: state.recentSessionCount,
                recentSessionTitles: state.recentSessionTitles,
                isInstalledOnHost: state.isInstalledOnHost,
                isProcessRunning: state.isProcessRunning,
                containerMatchCount: state.containerMatchCount,
                containerMatches: state.containerMatches
            )
        }
        if triggerReload {
            Task {
                let update = await sessionCoordinator.updateEnabledSources(enabledSources, environment: environment)
                await MainActor.run {
                    self.applyCoordinatorUpdate(update)
                }
            }
        }
    }

    public func shutdown() async {
        await sessionCoordinator.stop()
    }
    public func repairHooks(for source: AgentSource, environment: AgentEnvironment = .live()) async {
        guard let adapter = adapters.first(where: { $0.source == source }) else { return }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try await adapter.repairHooks(in: environment)
            }.value
            diagnosticsMessage = result.message
            await refreshAdapterSetupStates(environment: environment)
        } catch {
            diagnosticsMessage = "Failed to repair \(source.rawValue): \(error.localizedDescription)"
        }
    }

    public func repairAllEnabledSources(environment: AgentEnvironment = .live()) async {
        for source in enabledSources.sorted(by: { $0.rawValue < $1.rawValue }) {
            await repairHooks(for: source, environment: environment)
        }
    }

    public func rollbackHooks(for source: AgentSource, environment: AgentEnvironment = .live()) async {
        guard let adapter = adapters.first(where: { $0.source == source }) else { return }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try await adapter.rollbackHooks(in: environment)
            }.value
            diagnosticsMessage = result.message
            await refreshAdapterSetupStates(environment: environment)
        } catch {
            diagnosticsMessage = "Failed to rollback \(source.rawValue): \(error.localizedDescription)"
        }
    }

    public func rollbackAllManagedSources(environment: AgentEnvironment = .live()) async {
        for source in enabledSources.sorted(by: { $0.rawValue < $1.rawValue }) {
            await rollbackHooks(for: source, environment: environment)
        }
    }

    public func refreshHistory(for session: AgentSession, environment: AgentEnvironment = .live()) async {
        guard let adapter = sourceAdapter(for: session.source) else { return }
        do {
            let discovered = discoveredSession(for: session)
            let history = try await adapter.loadHistory(for: discovered, in: environment)
            sessionHistories[session.id] = history
        } catch {
            diagnosticsMessage = "Failed to load history for \(session.title): \(error.localizedDescription)"
        }
    }

    public func directSubmissionPlan(for session: AgentSession, response: String) -> DirectSubmissionPlan? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        switch session.source {
        case .codex:
            if let resumeCommand = session.resumeCommand, resumeCommand.isEmpty == false {
                return .terminalCommand("\(resumeCommand) \(shellEscape(trimmed))")
            }
            return .terminalCommand(shellCommand(
                executable: "codex",
                arguments: ["resume", session.sessionId, trimmed],
                workingDirectory: session.workingDirectory
            ))

        case .gemini:
            return .detachedCLI(
                executable: "gemini",
                arguments: ["--resume", session.sessionId, "--prompt", trimmed],
                workingDirectory: session.workingDirectory
            )

        case .claude:
            return .detachedCLI(
                executable: "/opt/homebrew/opt/node@24/bin/node",
                arguments: [claudeExecutablePath(), "--resume", session.sessionId, "--print", trimmed],
                workingDirectory: session.workingDirectory
            )

        default:
            if let resumeCommand = session.resumeCommand, resumeCommand.isEmpty == false {
                return .terminalCommand("\(resumeCommand) \(shellEscape(trimmed))")
            }
            return nil
        }
    }

    private func mutateSelected(_ body: (inout AgentSession) -> Void) {
        let targetID = selectedSession?.id ?? selectedSessionID
        guard let id = targetID, let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        var s = sessions[idx]
        body(&s)
        s.lastUpdated = .now
        sessions[idx] = s
        sessions.sort { $0.lastUpdated > $1.lastUpdated }
        if filteredSessions.contains(where: { $0.id == id }) == false {
            selectedSessionID = filteredSessions.first?.id ?? sessions.first?.id
        }
    }

    private func collectReloadResult(environment: AgentEnvironment) async -> ReloadResult {
        let adapters = self.adapters.filter { enabledSources.contains($0.source) }
        return await Task.detached(priority: .userInitiated) {
            var events: [AgentEvent] = []
            var failures: [String] = []

            for adapter in adapters {
                do {
                    let discovered = try await adapter.discoverSessions(in: environment)
                    for session in discovered {
                        do {
                            events.append(contentsOf: try await adapter.loadEvents(for: session, in: environment))
                        } catch {
                            failures.append("\(adapter.source.rawValue): \(session.sessionId): \(error.localizedDescription)")
                        }
                    }
                } catch {
                    failures.append("\(adapter.source.rawValue): \(error.localizedDescription)")
                }
            }

            let states = await loadAdapterSetupStates(adapters: adapters, environment: environment)
            return ReloadResult(events: events, setupStates: states, failures: failures)
        }.value
    }

    private func refreshSelectedHistory(environment: AgentEnvironment = .live()) async {
        guard let selectedSession else { return }
        await refreshHistory(for: selectedSession, environment: environment)
    }

    private func applyCoordinatorUpdate(_ update: SessionCoordinatorUpdate) {
        let oldAttentionCount = attentionSessions.count
        sessions = update.sessions

        if selectedSessionID == nil || sessions.contains(where: { $0.id == selectedSessionID }) == false {
            selectedSessionID = sessions.first?.id
        }

        if sessions.isEmpty {
            diagnosticsMessage = update.failures.isEmpty
                ? "No live sessions were found."
                : "No live sessions were found. Failures: \(update.failures.joined(separator: " | "))"
        } else {
            diagnosticsMessage = update.failures.isEmpty
                ? "Loaded \(sessions.count) live session(s)."
                : "Loaded \(sessions.count) live session(s). Failures: \(update.failures.joined(separator: " | "))"
        }

        if selectedSession != nil {
            Task {
                await refreshSelectedHistory()
            }
        }

        if oldAttentionCount == 0 && attentionSessions.count > 0 {
            NotificationCenter.default.post(name: NSNotification.Name("vibeIslandNeedsAttention"), object: nil)
        }
    }

    private func collectSetupStates(environment: AgentEnvironment) async -> [AdapterSetupState] {
        let adapters = self.adapters.filter { enabledSources.contains($0.source) }
        return await Task.detached(priority: .utility) {
            await loadAdapterSetupStates(adapters: adapters, environment: environment)
        }.value
    }

    private func isProbeSession(_ session: AgentSession) -> Bool {
        let haystack = [
            session.sessionId,
            session.title,
            session.workingDirectory ?? "",
            session.originPath ?? "",
            session.lastAssistantMessage ?? "",
        ]
        .joined(separator: " ")
        .lowercased()

        return haystack.contains("smoke")
            || haystack.contains("oss-smoke")
            || haystack.contains("ui-overlap-repro")
            || haystack.contains("bridge capture smoke test")
            || haystack.contains("health-check")
            || haystack.contains("healthcheck")
            || haystack.contains("probe")
            || haystack.contains("/tmp/")
    }

    private enum ApprovalChoiceFallback {
        case none
        case first
        case last
    }

    private func approvalChoice(matching terms: [String], fallback: ApprovalChoiceFallback) -> String? {
        guard let choices = selectedSession?.approvalPayload?.choices, choices.isEmpty == false else { return nil }
        if let matchingChoice = choices.first(where: { choice in
            let lowercased = choice.lowercased()
            return terms.contains(where: lowercased.contains)
        }) {
            return matchingChoice
        }

        switch fallback {
        case .none:
            return nil
        case .first:
            return choices.first
        case .last:
            return choices.last
        }
    }

    private func openCommandInTerminal(_ command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            """
            tell application "Terminal"
                activate
                do script "\(appleScriptEscaped(command))"
            end tell
            """
        ]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(domain: "AgentIsland.AppModel", code: Int(process.terminationStatus))
        }
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func submitSelectedText(_ text: String) async {
        guard let session = selectedSession else { return }

        do {
            if ClaudeHookTransport.shared.respondToInteraction(session: session, response: text) {
                    markSelectedSessionAsSubmitted(response: text)
                    diagnosticsMessage = "Submitted '\(text)' directly to \(session.source.displayName) via the live socket bridge."
                    soundEngine.play(.taskAcknowledge)
                    return
            }

            if let adapter = sourceAdapter(for: session.source) {
                let result = try await adapter.submitResponse(text, to: session, in: .live())
                if result.submittedDirectly {
                    markSelectedSessionAsSubmitted(response: text)
                    diagnosticsMessage = result.summary
                    soundEngine.play(.taskAcknowledge)
                    return
                }
            }

            guard let plan = directSubmissionPlan(for: session, response: text) else {
                copyAnswerFallback(text)
                return
            }

            try execute(plan: plan)
            markSelectedSessionAsSubmitted(response: text)
            diagnosticsMessage = "Submitted '\(text)' directly to \(session.source.displayName)."
            soundEngine.play(.taskAcknowledge)
        } catch {
            copyAnswerFallback(text)
            diagnosticsMessage = "Direct submit failed, so the answer was copied instead: \(error.localizedDescription)"
        }
    }

    public func markSelectedSessionAsSubmitted(response: String) {
        mutateSelected { session in
            if session.approvalPayload != nil || session.status == .waitingForApproval {
                session.approvalPayload = nil
                session.status = .runningTool
            }
            if session.questionPayload != nil || session.status == .waitingForInput {
                session.questionPayload = nil
                session.status = .runningTool
            }
            session.lastAssistantMessage = "Submitted from Agent Island: \(response)"
            session.timeline.append(
                AgentTimelineEntry(
                    kind: .system,
                    title: "Submitted from Agent Island",
                    detail: response,
                    timestamp: .now
                )
            )
            session.timeline = Array(session.timeline.suffix(18))
        }
    }

    private func execute(plan: DirectSubmissionPlan) throws {
        switch plan {
        case .terminalCommand(let command):
            try openCommandInTerminal(command)

        case .detachedCLI(let executable, let arguments, let workingDirectory):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
            if let workingDirectory, workingDirectory.isEmpty == false {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            }
            let nullOutput = FileHandle(forWritingAtPath: "/dev/null")
            process.standardOutput = nullOutput
            process.standardError = nullOutput
            process.standardInput = nil
            try process.run()
        }
    }

    private func copyAnswerFallback(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        soundEngine.play(.taskAcknowledge)
    }

    private func shellCommand(executable: String, arguments: [String], workingDirectory: String?) -> String {
        let executablePart = ([executable] + arguments).map(shellEscape).joined(separator: " ")
        guard let workingDirectory, workingDirectory.isEmpty == false else {
            return executablePart
        }
        return "cd \(shellEscape(workingDirectory)) && \(executablePart)"
    }

    private func shellEscape(_ value: String) -> String {
        if value.isEmpty {
            return "''"
        }

        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private func claudeExecutablePath() -> String {
        "/opt/homebrew/bin/claude"
    }

    private func claudeDecision(for response: String) -> (decision: String, reason: String?) {
        let normalized = response.lowercased()
        if normalized.contains("deny") || normalized.contains("reject") || normalized == "n" {
            return ("deny", "Denied from Agent Island")
        }
        return ("allow", nil)
    }

    private func sourceAdapter(for source: AgentSource) -> (any AgentSourceAdapter)? {
        adapters.first(where: { $0.source == source })
    }

    private func discoveredSession(for session: AgentSession) -> DiscoveredSession {
        DiscoveredSession(
            source: session.source,
            sessionId: session.sessionId,
            title: session.title,
            threadId: session.threadId,
            terminalSessionId: session.terminalSessionId,
            fileURL: session.originPath.map { URL(fileURLWithPath: $0) }
        )
    }

    private func fallbackJumpTarget(for session: AgentSession) -> AgentJumpTarget? {
        if let terminalSessionId = session.terminalSessionId {
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

    @discardableResult
    private func handleResolvedJumpTarget(_ target: AgentJumpTarget, session: AgentSession) -> Bool {
        switch target.kind {
        case .tmux:
            guard let identifier = target.identifier else { return false }
            return jumpViaAdapter(kind: .tmux, identifier: identifier, displayName: session.title)

        case .ide:
            guard let identifier = target.identifier else { return false }
            let kind = TerminalKind.inferred(from: identifier)
            switch kind {
            case .cursor:
                return jumpViaAdapter(kind: .cursor, identifier: identifier, displayName: session.title)
            case .vscode:
                return jumpViaAdapter(kind: .vscode, identifier: identifier, displayName: session.title)
            default:
                return false
            }

        case .terminalSession:
            guard let identifier = target.identifier else { return false }
            let inferredKind = TerminalKind.inferred(from: identifier)
            if inferredKind != .unknown, jumpViaAdapter(kind: inferredKind, identifier: identifier, displayName: session.title) {
                return true
            }
            for adapter in terminalRegistry.adapters where adapter.capability().isInstalled {
                if tryJump(using: adapter, identifier: identifier, displayName: session.title) {
                    return true
                }
            }
            return false

        case .resumeCommand:
            guard target.command != nil else { return false }
            resumeSelectedSession()
            return true

        case .workingDirectory:
            guard target.filePath != nil else { return false }
            openSelectedWorkingDirectory()
            return true

        case .log:
            guard target.filePath != nil else { return false }
            revealSelectedSessionLog()
            return true
        }
    }

    private func jumpViaAdapter(kind: TerminalKind, identifier: String, displayName: String) -> Bool {
        guard let adapter = terminalRegistry.adapter(for: kind), adapter.capability().isInstalled else {
            return false
        }
        return tryJump(using: adapter, identifier: identifier, displayName: displayName)
    }

    private func tryJump(using adapter: any TerminalAdapter, identifier: String, displayName: String) -> Bool {
        do {
            try adapter.jump(to: TerminalSessionDescriptor(kind: adapter.kind, identifier: identifier, displayName: displayName))
            soundEngine.play(.taskAcknowledge)
            diagnosticsMessage = "Jumped to \(displayName)."
            return true
        } catch {
            diagnosticsMessage = "Jump failed: \(error.localizedDescription)"
            return false
        }
    }

    private func persistSoundSettings() {
        guard let data = try? JSONEncoder().encode(soundSettings) else { return }
        defaults.set(data, forKey: soundSettingsDefaultsKey)
    }

    public static func preview() -> AppModel {
        let model = AppModel(sessions: [])
        let previewSessions = DemoFixtures.defaultEvents().reduce(into: [String: AgentSession]()) { partialResult, event in
            let key = "\(event.source.rawValue):\(event.sessionId)"
            var session = partialResult[key] ?? AgentSession(
                source: event.source,
                sessionId: event.sessionId,
                title: event.title,
                status: event.status,
                lastUpdated: event.timestamp
            )
            session.apply(event)
            partialResult[key] = session
        }
        model.sessions = previewSessions.values.sorted { $0.lastUpdated > $1.lastUpdated }
        model.selectedSessionID = model.sessions.first?.id
        model.showOnboarding = false
        model.islandExpanded = true
        model.autoDetectProbeSessions = false
        model.adapterSetupStates = [
            AdapterSetupState(source: .claude, status: .manual, message: "Claude hooks can be repaired for the preview build.", touchedPaths: ["~/.claude/settings.json"]),
            AdapterSetupState(source: .codex, status: .manual, message: "Codex hooks can be repaired for the preview build.", touchedPaths: ["~/.codex/hooks.json", "~/.codex/config.toml"]),
        ]
        return model
    }

    private static func loadSoundSettings(from defaults: UserDefaults) -> SoundSettings {
        guard let data = defaults.data(forKey: "app.agentisland.sound-settings")
            ?? defaults.data(forKey: "app.vibeisland.sound-settings"),
              let settings = try? JSONDecoder().decode(SoundSettings.self, from: data) else {
            return SoundSettings()
        }
        return settings
    }

    private static func defaultsHomeDirectory(defaults: UserDefaults) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
}

private func loadAdapterSetupStates(
    adapters: [any AgentSourceAdapter],
    environment: AgentEnvironment
) async -> [AdapterSetupState] {
    var states: [AdapterSetupState] = []
    for adapter in adapters {
        do {
            let result = try await adapter.installHooks(in: environment)
            states.append(AdapterSetupState(
                source: adapter.source,
                status: result.status,
                message: result.message,
                touchedPaths: result.touchedPaths
            ))
        } catch {
            states.append(AdapterSetupState(
                source: adapter.source,
                status: .unavailable,
                message: error.localizedDescription,
                touchedPaths: []
            ))
        }
    }
    return states.sorted { $0.source.rawValue < $1.source.rawValue }
}

private struct SourceDetectionSnapshot {
    let runtime: RuntimeDetectionState
    let states: [SourceSelectionState]
}

private func detectSelectableSources(
    environment: AgentEnvironment,
    enabledSources: Set<AgentSource>,
    adapters: [any AgentSourceAdapter]
) async -> SourceDetectionSnapshot {
    let fileManager = FileManager.default
    let sources = AgentSource.visibleProductSources
    let runtime = detectRuntimeState()

    var states: [SourceSelectionState] = []
    for source in sources {
        let touchedPaths: [String]
        let fallbackDetected: Bool

        switch source {
        case .claude:
            touchedPaths = [
                environment.homeDirectory.appendingPathComponent(".claude/settings.json").path,
                environment.homeDirectory.appendingPathComponent(".agent-island/events/claude").path,
            ]
            fallbackDetected = touchedPaths.contains { fileManager.fileExists(atPath: $0) }

        case .codex:
            touchedPaths = [
                environment.homeDirectory.appendingPathComponent(".codex/session_index.jsonl").path,
                environment.homeDirectory.appendingPathComponent(".codex/config.toml").path,
                environment.homeDirectory.appendingPathComponent(".codex/hooks.json").path,
            ]
            fallbackDetected = touchedPaths.contains { fileManager.fileExists(atPath: $0) }

        case .gemini:
            touchedPaths = [
                environment.homeDirectory.appendingPathComponent(".gemini/settings.json").path,
                environment.homeDirectory.appendingPathComponent(".gemini/tmp").path,
            ]
            fallbackDetected = touchedPaths.contains { fileManager.fileExists(atPath: $0) }

        case .openclaw:
            touchedPaths = [
                environment.homeDirectory.appendingPathComponent(".openclaw/openclaw.json").path,
                environment.homeDirectory.appendingPathComponent(".config/opencode/opencode.json").path,
                environment.homeDirectory.appendingPathComponent(".config/opencode/plugins/agent-island.js").path,
                environment.homeDirectory.appendingPathComponent(".local/share/opencode/opencode.db").path,
                environment.homeDirectory.appendingPathComponent(".agent-island/events/openclaw").path,
            ]
            fallbackDetected = touchedPaths.contains { fileManager.fileExists(atPath: $0) }

        case .cursor:
            touchedPaths = [
                "/Applications/Cursor.app",
                NSHomeDirectory() + "/Applications/Cursor.app",
                environment.workingDirectory.appendingPathComponent("Extensions/terminal-focus/package.json").path,
            ]
            fallbackDetected = touchedPaths.contains { fileManager.fileExists(atPath: $0) }

        case .copilot:
            touchedPaths = [
                NSHomeDirectory() + "/.vscode/extensions",
                NSHomeDirectory() + "/.cursor/extensions",
                NSHomeDirectory() + "/.vscode-insiders/extensions",
            ]
            fallbackDetected = touchedPaths.contains { path in
                guard fileManager.fileExists(atPath: path) else { return false }
                guard let entries = try? fileManager.contentsOfDirectory(atPath: path) else { return false }
                return entries.contains(where: { $0.lowercased().contains("copilot") })
            }

        default:
            touchedPaths = []
            fallbackDetected = false
        }

        let isInstalledOnHost = touchedPaths.contains { fileManager.fileExists(atPath: $0) }
        let isProcessRunning = detectRunningProcess(for: source)

        let adapter = adapters.first { $0.source == source }
        let discoveredSessions: [DiscoveredSession]
        let discoveryFailure: String?

        if let adapter {
            do {
                discoveredSessions = try await adapter.discoverSessions(in: environment)
                discoveryFailure = nil
            } catch {
                discoveredSessions = []
                discoveryFailure = error.localizedDescription
            }
        } else {
            discoveredSessions = []
            discoveryFailure = nil
        }

        let recentSessionTitles = Array(discoveredSessions.prefix(6).map(\.title))
        let recentSessionCount = discoveredSessions.count
        let isDetected = fallbackDetected || recentSessionCount > 0 || isProcessRunning
        let detail: String
        let sourceName = source.displayName
        if let discoveryFailure {
            detail = "Detected local \(sourceName) files, but listing sessions failed: \(discoveryFailure)"
        } else if recentSessionCount > 0 {
            detail = "Detected \(recentSessionCount) recent \(sourceName) session(s) on this Mac."
        } else if isProcessRunning {
            detail = "\(sourceName) looks installed and running, but there is no active local session feed yet."
        } else if isDetected {
            detail = "Detected local \(sourceName) configuration on this Mac."
        } else {
            detail = "No local \(sourceName) installation or session cache was detected on this Mac. \(runtime.dockerMessage)"
        }

        states.append(SourceSelectionState(
            source: source,
            isDetected: isDetected,
            isEnabled: enabledSources.contains(source),
            detail: detail,
            touchedPaths: touchedPaths,
            recentSessionCount: recentSessionCount,
            recentSessionTitles: recentSessionTitles,
            isInstalledOnHost: isInstalledOnHost,
            isProcessRunning: isProcessRunning,
            containerMatchCount: 0,
            containerMatches: []
        ))
    }
    return SourceDetectionSnapshot(
        runtime: runtime,
        states: states.sorted {
            if $0.source.supportLevel != $1.source.supportLevel {
                return rank(for: $0.source.supportLevel) < rank(for: $1.source.supportLevel)
            }
            return $0.source.rawValue < $1.source.rawValue
        }
    )
}

private func rank(for supportLevel: AgentSupportLevel) -> Int {
    switch supportLevel {
    case .supported:
        return 0
    case .experimental:
        return 1
    case .hidden:
        return 2
    }
}

private func detectRuntimeState() -> RuntimeDetectionState {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["docker", "ps", "--format", "{{.ID}}"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus == 0 {
            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return RuntimeDetectionState(dockerAvailable: true, dockerMessage: "Docker is available, but there are no running containers.")
            }
            return RuntimeDetectionState(dockerAvailable: true, dockerMessage: "Docker is available.")
        }
        return RuntimeDetectionState(dockerAvailable: false, dockerMessage: "Docker daemon is unavailable or not started.")
    } catch {
        return RuntimeDetectionState(dockerAvailable: false, dockerMessage: "Docker daemon is unavailable or not started.")
    }
}

private func detectRunningProcess(for source: AgentSource) -> Bool {
    let patterns: [String]
    switch source {
    case .claude:
        patterns = ["claude", "Claude Code"]
    case .codex:
        patterns = ["Codex.app", "codex app-server", "(codex)"]
    case .gemini:
        patterns = ["gemini"]
    case .openclaw:
        patterns = ["openclaw", "opencode"]
    case .cursor:
        patterns = ["Cursor.app", "Cursor"]
    case .copilot:
        patterns = ["copilot", "GitHub Copilot"]
    default:
        patterns = [source.rawValue]
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", "ps -axo command | rg '\(patterns.joined(separator: "|"))'"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return process.terminationStatus == 0 && output.isEmpty == false
    } catch {
        return false
    }
}
