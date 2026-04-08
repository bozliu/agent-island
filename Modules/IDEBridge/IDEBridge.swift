import AgentCore
import Foundation
import SourceAdapters
import TerminalAdapters

public enum IDEKind: String, Codable, CaseIterable, Sendable, Hashable {
    case vscode
    case cursor
}

public struct IDEExtensionDescriptor: Sendable, Hashable, Codable {
    public let kind: IDEKind
    public let identifier: String
    public let displayName: String
    public let installHint: String

    public init(kind: IDEKind, identifier: String, displayName: String, installHint: String) {
        self.kind = kind
        self.identifier = identifier
        self.displayName = displayName
        self.installHint = installHint
    }
}

public enum BridgeCommand: Sendable, Hashable {
    case inspect
    case inspectLive
    case listSources
    case installIDEBridge(IDEKind)
    case emitDemoEvent(AgentSource)
    case captureEvent(AgentSource)
}

public struct IDEBridgeInstaller {
    public static let supportedExtensions: [IDEExtensionDescriptor] = [
        IDEExtensionDescriptor(
            kind: .vscode,
            identifier: "agent-island.terminal-focus",
            displayName: "Agent Island Terminal Focus",
            installHint: "Package the extension under Extensions/terminal-focus and install it with `code --install-extension`."
        ),
        IDEExtensionDescriptor(
            kind: .cursor,
            identifier: "agent-island.terminal-focus",
            displayName: "Agent Island Terminal Focus",
            installHint: "Cursor consumes the same VS Code compatible extension package."
        ),
    ]

    public init() {}

    public func descriptor(for kind: IDEKind) -> IDEExtensionDescriptor? {
        Self.supportedExtensions.first { $0.kind == kind }
    }
}

public struct BridgeInspection: Codable, Sendable {
    public let environment: AgentEnvironment
    public let terminalCapabilities: [TerminalCapabilityRecord]
    public let supportedSources: [String]

    public init(environment: AgentEnvironment, terminalCapabilities: [TerminalCapabilityRecord], supportedSources: [String]) {
        self.environment = environment
        self.terminalCapabilities = terminalCapabilities
        self.supportedSources = supportedSources
    }
}

public struct TerminalCapabilityRecord: Codable, Sendable {
    public let kind: String
    public let installed: Bool
    public let preciseJump: Bool
    public let notes: String

    public init(kind: String, installed: Bool, preciseJump: Bool, notes: String) {
        self.kind = kind
        self.installed = installed
        self.preciseJump = preciseJump
        self.notes = notes
    }
}

public enum BridgeCommandDispatcher {
    public static func run(
        _ command: BridgeCommand,
        environment: AgentEnvironment = .live(),
        terminalRegistry: TerminalAdapterRegistry = .live()
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        switch command {
        case .inspect:
            let report = BridgeInspection(
                environment: environment,
                terminalCapabilities: terminalRegistry.capabilityReport().map {
                    TerminalCapabilityRecord(
                        kind: $0.kind.rawValue,
                        installed: $0.isInstalled,
                        preciseJump: $0.supportsPreciseJump,
                        notes: $0.notes ?? ""
                    )
                },
                supportedSources: AgentSource.allCases.map(\.rawValue)
            )
            return String(decoding: try encoder.encode(report), as: UTF8.self)

        case .inspectLive:
            let adapters = AgentSourceAdapterFactory.production()
            let report = try awaitLiveInspection(adapters: adapters, environment: environment)
            return report

        case .listSources:
            return AgentSource.allCases.map(\.rawValue).joined(separator: "\n")

        case .installIDEBridge(let ideKind):
            let installer = IDEBridgeInstaller()
            guard let descriptor = installer.descriptor(for: ideKind) else {
                throw NSError(domain: "AgentIsland.IDEBridge", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported IDE: \(ideKind.rawValue)"
                ])
            }
            return "\(descriptor.displayName)\n\(descriptor.installHint)"

        case .emitDemoEvent(let source):
            let events = DemoFixtures.defaultEvents().filter { $0.source == source }
            return String(decoding: try encoder.encode(events), as: UTF8.self)

        case .captureEvent(let source):
            let capture = try makeBridgeCapture(source: source)
            try persistBridgeCapture(capture, in: environment, encoder: encoder)
            return "{}"
        }
    }
}

private func awaitLiveInspection(
    adapters: [any AgentSourceAdapter],
    environment: AgentEnvironment
) throws -> String {
    final class OutputBox: @unchecked Sendable {
        var value = ""
    }

    let semaphore = DispatchSemaphore(value: 0)
    let output = OutputBox()

    Task.detached {
        var lines: [String] = []
        for adapter in adapters {
            do {
                let sessions = try await adapter.discoverSessions(in: environment)
                lines.append("SOURCE \(adapter.source.rawValue) COUNT \(sessions.count)")
                for session in sessions.prefix(6) {
                    do {
                        let events = try await adapter.loadEvents(for: session, in: environment)
                        lines.append("  - \(session.sessionId) | \(session.title) | events=\(events.count)")
                    } catch {
                        lines.append("  - \(session.sessionId) | \(session.title) | ERROR \(error.localizedDescription)")
                    }
                }
            } catch {
                lines.append("SOURCE \(adapter.source.rawValue) ERROR \(error.localizedDescription)")
            }
        }
        output.value = lines.joined(separator: "\n")
        semaphore.signal()
    }

    semaphore.wait()
    return output.value
}

private func makeBridgeCapture(source: AgentSource) throws -> AgentBridgeCapture {
    let environment = ProcessInfo.processInfo.environment
    let inputData = FileHandle.standardInput.readDataToEndOfFile()
    let rawInput = String(data: inputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let inputObject = rawInput.flatMap { try? bridgeJSONObject(from: Data($0.utf8)) }

    let hookName = firstNonEmpty([
        environment["VIBE_ISLAND_HOOK_NAME"],
        environment["CLAUDE_HOOK_EVENT_NAME"],
        environment["GEMINI_HOOK_EVENT_NAME"],
        environment["CODEX_HOOK_EVENT_NAME"],
        recursiveString(in: inputObject, keys: ["hook_event_name", "hookEventName", "hook", "event"]),
    ])
    let sessionId = firstNonEmpty([
        environment["VIBE_ISLAND_SESSION_ID"],
        environment["SESSION_ID"],
        recursiveString(in: inputObject, keys: ["session_id", "sessionId", "conversation_id", "conversationId"]),
    ])
    let cwd = firstNonEmpty([
        environment["PWD"],
        environment["VIBE_ISLAND_CWD"],
        recursiveString(in: inputObject, keys: ["cwd", "working_directory", "workingDirectory", "workdir"]),
    ])
    let terminalSessionId = firstNonEmpty([
        environment["VIBE_ISLAND_TERMINAL_SESSION_ID"],
        recursiveString(in: inputObject, keys: ["terminal_session_id", "terminalSessionId"]),
    ])
    let toolName = firstNonEmpty([
        recursiveString(in: inputObject, keys: ["tool_name", "toolName", "name"]),
    ])
    let message = firstNonEmpty([
        recursiveString(in: inputObject, keys: ["message", "summary", "content", "prompt", "description"]),
        rawInput.flatMap { compactWhitespace($0) },
    ])
    let title = firstNonEmpty([
        recursiveString(in: inputObject, keys: ["title", "thread_name", "threadName"]),
        message,
    ])
    let metadata = filteredBridgeMetadata(from: environment)
    return AgentBridgeCapture(
        source: source,
        sessionId: sessionId,
        hookName: hookName,
        cwd: cwd,
        title: title,
        message: message,
        toolName: toolName,
        terminalSessionId: terminalSessionId,
        status: inferStatus(source: source, hookName: hookName, input: inputObject, rawInput: rawInput),
        rawInput: rawInput,
        metadata: metadata,
        timestamp: Date()
    )
}

private func persistBridgeCapture(_ capture: AgentBridgeCapture, in environment: AgentEnvironment, encoder: JSONEncoder) throws {
    let dayFormatter = DateFormatter()
    dayFormatter.calendar = Calendar(identifier: .iso8601)
    dayFormatter.locale = Locale(identifier: "en_US_POSIX")
    dayFormatter.dateFormat = "yyyy-MM-dd"

    let directory = environment.homeDirectory
        .appendingPathComponent(".agent-island", isDirectory: true)
        .appendingPathComponent("events", isDirectory: true)
        .appendingPathComponent(capture.source.rawValue, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

    let fileURL = directory.appendingPathComponent("\(dayFormatter.string(from: capture.timestamp)).jsonl")
    let lineEncoder = JSONEncoder()
    lineEncoder.outputFormatting = [.sortedKeys]
    lineEncoder.dateEncodingStrategy = encoder.dateEncodingStrategy
    let data = try lineEncoder.encode(capture)
    var line = Data()
    if FileManager.default.fileExists(atPath: fileURL.path), (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0 > 0 {
        line.append(Data("\n".utf8))
    }
    line.append(data)

    if FileManager.default.fileExists(atPath: fileURL.path) {
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
        try handle.close()
    } else {
        try line.write(to: fileURL, options: .atomic)
    }
}

private func inferStatus(source: AgentSource, hookName: String?, input: [String: Any]?, rawInput: String?) -> AgentStatus {
    let loweredHook = hookName?.lowercased() ?? ""
    let loweredInput = rawInput?.lowercased() ?? ""

    if loweredHook.contains("permission") || loweredHook.contains("approval") {
        return .waitingForApproval
    }
    if loweredHook.contains("question") || loweredHook.contains("input") {
        return .waitingForInput
    }
    if loweredHook.contains("tool") {
        if loweredHook.contains("post") || loweredHook.contains("after") {
            return .thinking
        }
        return .runningTool
    }
    if loweredHook.contains("stop") || loweredHook.contains("end") {
        return .complete
    }
    if loweredHook.contains("compact") {
        return .compacting
    }
    if loweredInput.contains("\"error\"") {
        return .error
    }
    if source == .gemini, recursiveString(in: input, keys: ["tool_name", "toolName"]) != nil {
        return .runningTool
    }
    return .thinking
}

private func filteredBridgeMetadata(from environment: [String: String]) -> [String: String] {
    environment
        .filter { key, _ in
            key.hasPrefix("CLAUDE_")
                || key.hasPrefix("GEMINI")
                || key.hasPrefix("CODEX")
                || key.hasPrefix("VIBE_")
                || key == "PWD"
        }
        .reduce(into: [String: String]()) { partialResult, pair in
            partialResult[pair.key] = pair.value
        }
}

private func compactWhitespace(_ text: String) -> String? {
    let collapsed = text
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return collapsed.isEmpty ? nil : collapsed
}

private func firstNonEmpty(_ values: [String?]) -> String? {
    for value in values {
        guard let value, let compact = compactWhitespace(value) else { continue }
        return compact
    }
    return nil
}

private func recursiveString(in value: Any?, keys: Set<String>) -> String? {
    if let dict = value as? [String: Any] {
        for (key, nested) in dict {
            if keys.contains(key), let string = nested as? String, string.isEmpty == false {
                return string
            }
            if let nestedValue = recursiveString(in: nested, keys: keys) {
                return nestedValue
            }
        }
    } else if let array = value as? [Any] {
        for item in array {
            if let nestedValue = recursiveString(in: item, keys: keys) {
                return nestedValue
            }
        }
    }
    return nil
}

private func bridgeJSONObject(from data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw NSError(domain: "AgentIsland.IDEBridge", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Expected JSON object from hook input."
        ])
    }
    return object
}
