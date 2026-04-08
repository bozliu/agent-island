import AgentCore
import Foundation
import TerminalAdapters

public struct DiagnosticsSettingsSnapshot: Codable, Sendable, Hashable {
    public let dashboardMode: String
    public let layoutMode: String
    public let displayTarget: String
    public let showUsage: Bool
    public let smartSuppressionEnabled: Bool
    public let showAgentDetail: Bool

    public init(
        dashboardMode: String,
        layoutMode: String,
        displayTarget: String,
        showUsage: Bool,
        smartSuppressionEnabled: Bool,
        showAgentDetail: Bool
    ) {
        self.dashboardMode = dashboardMode
        self.layoutMode = layoutMode
        self.displayTarget = displayTarget
        self.showUsage = showUsage
        self.smartSuppressionEnabled = smartSuppressionEnabled
        self.showAgentDetail = showAgentDetail
    }
}

private struct DiagnosticsSetupState: Codable, Sendable {
    let source: String
    let status: String
    let message: String
    let touchedPaths: [String]
}

private struct DiagnosticsPayload: Encodable, Sendable {
    let exportedAt: Date
    let sessions: [AgentSession]
    let setupStates: [DiagnosticsSetupState]
    let terminalCapabilities: [TerminalCapability]
    let environment: AgentEnvironment
    let settings: DiagnosticsSettingsSnapshot
}

public enum DiagnosticsExporter {
    public static func export(
        sessions: [AgentSession],
        setupStates: [AdapterSetupState],
        terminalCapabilities: [TerminalCapability],
        environment: AgentEnvironment,
        settings: DiagnosticsSettingsSnapshot
    ) throws -> URL {
        let payload = DiagnosticsPayload(
            exportedAt: Date(),
            sessions: sessions,
            setupStates: setupStates.map {
                DiagnosticsSetupState(
                    source: $0.source.rawValue,
                    status: $0.status.rawValue,
                    message: $0.message,
                    touchedPaths: $0.touchedPaths
                )
            },
            terminalCapabilities: terminalCapabilities,
            environment: environment,
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let filenameFormatter = DateFormatter()
        filenameFormatter.calendar = Calendar(identifier: .iso8601)
        filenameFormatter.locale = Locale(identifier: "en_US_POSIX")
        filenameFormatter.dateFormat = "yyyyMMdd-HHmmss"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-island-diagnostics-\(filenameFormatter.string(from: Date())).json")
        try encoder.encode(payload).write(to: url, options: .atomic)
        return url
    }
}
