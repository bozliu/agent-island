import Foundation

public struct AgentSourceCapabilities: Codable, Sendable, Hashable {
    public let supportsRealtimeUpdates: Bool
    public let supportsDirectSubmit: Bool
    public let supportsHistory: Bool
    public let supportsJump: Bool
    public let supportsAutoInstall: Bool

    public init(
        supportsRealtimeUpdates: Bool,
        supportsDirectSubmit: Bool,
        supportsHistory: Bool,
        supportsJump: Bool,
        supportsAutoInstall: Bool
    ) {
        self.supportsRealtimeUpdates = supportsRealtimeUpdates
        self.supportsDirectSubmit = supportsDirectSubmit
        self.supportsHistory = supportsHistory
        self.supportsJump = supportsJump
        self.supportsAutoInstall = supportsAutoInstall
    }
}

public enum AgentHistoryItemKind: String, Codable, CaseIterable, Sendable, Hashable {
    case user
    case assistant
    case tool
    case system
    case markdown
}

public struct AgentHistoryItem: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let kind: AgentHistoryItemKind
    public let title: String
    public let body: String?
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        kind: AgentHistoryItemKind,
        title: String,
        body: String? = nil,
        timestamp: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.timestamp = timestamp
    }
}

public enum AgentJumpTargetKind: String, Codable, CaseIterable, Sendable, Hashable {
    case tmux
    case terminalSession
    case ide
    case resumeCommand
    case workingDirectory
    case log
}

public struct AgentJumpTarget: Codable, Sendable, Hashable {
    public let kind: AgentJumpTargetKind
    public let label: String
    public let identifier: String?
    public let command: String?
    public let filePath: String?

    public init(
        kind: AgentJumpTargetKind,
        label: String,
        identifier: String? = nil,
        command: String? = nil,
        filePath: String? = nil
    ) {
        self.kind = kind
        self.label = label
        self.identifier = identifier
        self.command = command
        self.filePath = filePath
    }
}

public struct AgentSubmitResponseResult: Codable, Sendable, Hashable {
    public let submittedDirectly: Bool
    public let summary: String

    public init(submittedDirectly: Bool, summary: String) {
        self.submittedDirectly = submittedDirectly
        self.summary = summary
    }
}
