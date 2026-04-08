import AgentCore
import Foundation

private struct ClaudeHookSocketResponse: Codable, Sendable {
    let decision: String
    let reason: String?
}

private struct OpenClawHookDecisionEnvelope: Codable, Sendable {
    let hookSpecificOutput: OpenClawHookDecision
}

private struct OpenClawHookDecision: Codable, Sendable {
    let decision: OpenClawDecisionPayload
}

private struct OpenClawDecisionPayload: Codable, Sendable {
    let behavior: String?
    let reason: String?
    let updatedInput: OpenClawUpdatedInput?
}

private struct OpenClawUpdatedInput: Codable, Sendable {
    let answers: [String: String]
}

private enum PendingInteractionKind: Sendable {
    case claudePermission
    case openClawPermission
    case openClawQuestion(headers: [String])
}

private struct PendingInteraction: Sendable {
    let source: AgentSource
    let socket: Int32
    let kind: PendingInteractionKind
}

private struct ParsedHookMessage: Sendable {
    let sessionId: String
    let capture: AgentBridgeCapture
    let pendingInteraction: PendingInteraction?
}

public final class ClaudeHookTransport: @unchecked Sendable {
    public static let shared = ClaudeHookTransport()
    public static let socketPath = "/tmp/agent-island.sock"
    public static let legacySocketPath = "/tmp/vibe-island.sock"

    private let queue = DispatchQueue(label: "app.vibeisland.socket-transport", qos: .userInitiated)
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var pendingInteractions: [String: PendingInteraction] = [:]
    private let interactionLock = NSLock()
    private var captureListeners: [UUID: @Sendable (AgentBridgeCapture) -> Void] = [:]

    private init() {}

    public func start() {
        queue.async { [weak self] in
            self?.startServerIfNeeded()
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.shutdown()
        }
    }

    public func addCaptureListener(_ listener: @escaping @Sendable (AgentBridgeCapture) -> Void) -> UUID {
        let token = UUID()
        queue.async { [weak self] in
            self?.captureListeners[token] = listener
        }
        return token
    }

    public func removeCaptureListener(_ token: UUID) {
        queue.async { [weak self] in
            self?.captureListeners.removeValue(forKey: token)
        }
    }

    public func respondToPermission(sessionId: String, decision: String, reason: String? = nil) -> Bool {
        interactionLock.lock()
        guard let pending = pendingInteractions.removeValue(forKey: sessionId) else {
            interactionLock.unlock()
            return false
        }
        interactionLock.unlock()

        let payload: Data?
        switch pending.kind {
        case .claudePermission:
            payload = try? JSONEncoder().encode(ClaudeHookSocketResponse(decision: decision, reason: reason))
        case .openClawPermission:
            payload = try? JSONEncoder().encode(
                OpenClawHookDecisionEnvelope(
                    hookSpecificOutput: OpenClawHookDecision(
                        decision: OpenClawDecisionPayload(
                            behavior: openClawBehavior(for: decision),
                            reason: reason,
                            updatedInput: nil
                        )
                    )
                )
            )
        case .openClawQuestion:
            payload = nil
        }

        guard let payload else {
            close(pending.socket)
            return false
        }

        let sent = payload.withUnsafeBytes { buffer in
            send(pending.socket, buffer.baseAddress, buffer.count, 0)
        }
        close(pending.socket)
        return sent >= 0
    }

    public func respondToInteraction(session: AgentSession, response: String) -> Bool {
        interactionLock.lock()
        guard let pending = pendingInteractions.removeValue(forKey: session.sessionId) else {
            interactionLock.unlock()
            return false
        }
        interactionLock.unlock()

        let payload: Data?
        switch pending.kind {
        case .claudePermission:
            let decision = response.lowercased().contains("deny") || response.lowercased().contains("reject") ? "deny" : "allow"
            let reason = decision == "deny" ? "Denied from Agent Island" : nil
            payload = try? JSONEncoder().encode(ClaudeHookSocketResponse(decision: decision, reason: reason))

        case .openClawPermission:
            let behavior = openClawBehavior(for: response)
            let reason = behavior == "deny" ? "Denied from Agent Island" : nil
            payload = try? JSONEncoder().encode(
                OpenClawHookDecisionEnvelope(
                    hookSpecificOutput: OpenClawHookDecision(
                        decision: OpenClawDecisionPayload(
                            behavior: behavior,
                            reason: reason,
                            updatedInput: nil
                        )
                    )
                )
            )

        case .openClawQuestion(let headers):
            let headerKeys = headers.isEmpty ? ["answer"] : headers
            var answers: [String: String] = [:]
            for header in headerKeys {
                answers[header] = response
            }
            payload = try? JSONEncoder().encode(
                OpenClawHookDecisionEnvelope(
                    hookSpecificOutput: OpenClawHookDecision(
                        decision: OpenClawDecisionPayload(
                            behavior: nil,
                            reason: nil,
                            updatedInput: OpenClawUpdatedInput(answers: answers)
                        )
                    )
                )
            )
        }

        guard let payload else {
            close(pending.socket)
            return false
        }

        let sent = payload.withUnsafeBytes { buffer in
            send(pending.socket, buffer.baseAddress, buffer.count, 0)
        }
        close(pending.socket)
        return sent >= 0
    }

    private func startServerIfNeeded() {
        guard serverSocket < 0 else { return }

        unlink(Self.socketPath)
        unlink(Self.legacySocketPath)
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { return }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        Self.socketPath.withCString { pathPtr in
            withUnsafeMutablePointer(to: &address.sun_path) { sunPath in
                let buffer = UnsafeMutableRawPointer(sunPath).assumingMemoryBound(to: CChar.self)
                strcpy(buffer, pathPtr)
            }
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(serverSocket, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0, listen(serverSocket, 10) == 0 else {
            close(serverSocket)
            serverSocket = -1
            return
        }

        chmod(Self.socketPath, 0o777)
        symlink(Self.socketPath, Self.legacySocketPath)

        acceptSource = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: queue)
        acceptSource?.setEventHandler { [weak self] in
            self?.acceptClient()
        }
        acceptSource?.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.serverSocket >= 0 {
                close(self.serverSocket)
                self.serverSocket = -1
            }
        }
        acceptSource?.resume()
    }

    private func shutdown() {
        acceptSource?.cancel()
        acceptSource = nil
        interactionLock.lock()
        for pending in pendingInteractions.values {
            close(pending.socket)
        }
        pendingInteractions.removeAll()
        interactionLock.unlock()
        unlink(Self.socketPath)
        unlink(Self.legacySocketPath)
    }

    private func acceptClient() {
        var storage = sockaddr()
        var length: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
        let clientSocket = withUnsafeMutablePointer(to: &storage) { pointer in
            accept(serverSocket, pointer, &length)
        }
        guard clientSocket >= 0 else { return }

        guard let data = readAvailableData(from: clientSocket) else {
            close(clientSocket)
            return
        }

        guard let message = parseIncomingMessage(from: data, socket: clientSocket) else {
            close(clientSocket)
            return
        }

        persist(capture: message.capture)
        broadcast(capture: message.capture)

        if let pendingInteraction = message.pendingInteraction {
            interactionLock.lock()
            pendingInteractions[message.sessionId] = pendingInteraction
            interactionLock.unlock()
        } else {
            close(clientSocket)
        }

        NotificationCenter.default.post(name: .vibeIslandHookEventReceived, object: message.sessionId)
    }

    private func readAvailableData(from socket: Int32) -> Data? {
        var buffer = [UInt8](repeating: 0, count: 16384)
        let count = recv(socket, &buffer, buffer.count, 0)
        guard count > 0 else { return nil }
        return Data(buffer.prefix(Int(count)))
    }

    private func parseIncomingMessage(from data: Data, socket: Int32) -> ParsedHookMessage? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let rawSource = (object["_source"] as? String)?.lowercased()
        let source: AgentSource = {
            switch rawSource {
            case "opencode", "openclaw":
                return .openclaw
            default:
                return .claude
            }
        }()

        guard let sessionId = object["session_id"] as? String, sessionId.isEmpty == false else {
            return nil
        }

        switch source {
        case .claude:
            return parseClaudeMessage(object: object, sessionId: sessionId, socket: socket)
        case .openclaw:
            return parseOpenClawMessage(object: object, sessionId: sessionId, socket: socket)
        default:
            return nil
        }
    }

    private func parseClaudeMessage(object: [String: Any], sessionId: String, socket: Int32) -> ParsedHookMessage {
        let status = mapClaudeSocketStatus(object["status"] as? String ?? "")
        let tool = object["tool"] as? String
        let message = object["message"] as? String
        let capture = AgentBridgeCapture(
            source: .claude,
            sessionId: sessionId,
            hookName: object["event"] as? String,
            cwd: object["cwd"] as? String,
            title: message ?? tool ?? (object["event"] as? String),
            message: message ?? tool,
            toolName: tool,
            terminalSessionId: nil,
            status: status,
            rawInput: nil,
            metadata: [
                "pid": stringify(object["pid"]),
                "tty": object["tty"] as? String ?? "",
                "tool_use_id": object["tool_use_id"] as? String ?? "",
            ],
            timestamp: .now
        )
        let pending: PendingInteraction? = status == .waitingForApproval ? PendingInteraction(source: .claude, socket: socket, kind: .claudePermission) : nil
        return ParsedHookMessage(sessionId: sessionId, capture: capture, pendingInteraction: pending)
    }

    private func parseOpenClawMessage(object: [String: Any], sessionId: String, socket: Int32) -> ParsedHookMessage {
        let hookName = object["hook_event_name"] as? String ?? object["event"] as? String ?? "event"
        let toolName = object["tool_name"] as? String ?? object["tool"] as? String
        let prompt = object["prompt"] as? String
        let cwd = object["cwd"] as? String
        let toolInput = object["tool_input"] as? [String: Any]

        let status: AgentStatus
        let requestKind: String
        let pendingKind: PendingInteractionKind?
        var metadata: [String: String] = [
            "_source": "openclaw",
            "tty": object["_tty"] as? String ?? "",
            "server_port": stringify(object["_server_port"]),
        ]
        var message = prompt ?? compactWhitespace(toolName)

        switch hookName {
        case "PermissionRequest":
            if toolName == "AskUserQuestion" {
                status = .waitingForInput
                requestKind = "question"
                let questions = (toolInput?["questions"] as? [[String: Any]]) ?? []
                let promptText = questions.compactMap { $0["question"] as? String }.joined(separator: "\n")
                let headers = questions.compactMap { $0["header"] as? String }
                let options = questions.flatMap { question -> [String] in
                    ((question["options"] as? [[String: Any]]) ?? []).compactMap { $0["label"] as? String }
                }
                metadata["question_prompt"] = promptText
                metadata["question_headers"] = jsonString(from: headers) ?? "[]"
                metadata["question_options"] = jsonString(from: options) ?? "[]"
                metadata["detail"] = promptText
                message = promptText.isEmpty ? "OpenCode is waiting for an answer." : promptText
                pendingKind = .openClawQuestion(headers: headers)
            } else {
                status = .waitingForApproval
                requestKind = "approval"
                let detail = compactWhitespace(toolInput.flatMap { jsonString(from: $0) } ?? toolName) ?? "OpenCode is waiting for approval."
                metadata["detail"] = detail
                message = detail
                pendingKind = .openClawPermission
            }

        case "PreToolUse":
            status = .runningTool
            requestKind = "tool"
            metadata["detail"] = compactWhitespace(toolInput.flatMap { jsonString(from: $0) } ?? toolName) ?? ""
            pendingKind = nil

        case "PostToolUse":
            status = .thinking
            requestKind = "tool"
            metadata["detail"] = compactWhitespace(toolInput.flatMap { jsonString(from: $0) } ?? toolName) ?? ""
            pendingKind = nil

        case "SessionEnd", "Stop":
            status = .complete
            requestKind = "system"
            pendingKind = nil

        case "SessionStart":
            status = .idle
            requestKind = "system"
            pendingKind = nil

        default:
            status = .thinking
            requestKind = "system"
            pendingKind = nil
        }

        metadata["request_kind"] = requestKind

        let capture = AgentBridgeCapture(
            source: .openclaw,
            sessionId: sessionId,
            hookName: hookName,
            cwd: cwd,
            title: message ?? toolName ?? hookName,
            message: message ?? toolName,
            toolName: toolName,
            terminalSessionId: nil,
            status: status,
            rawInput: nil,
            metadata: metadata,
            timestamp: .now
        )

        let pending = pendingKind.map { PendingInteraction(source: .openclaw, socket: socket, kind: $0) }
        return ParsedHookMessage(sessionId: sessionId, capture: capture, pendingInteraction: pending)
    }

    private func persist(capture: AgentBridgeCapture) {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agent-island", isDirectory: true)
            .appendingPathComponent("events", isDirectory: true)
            .appendingPathComponent(capture.source.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let fileURL = directory.appendingPathComponent("\(formatter.string(from: Date())).jsonl")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let line = try? encoder.encode(capture) else { return }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data("\n".utf8))
                try? handle.write(contentsOf: line)
                try? handle.close()
            }
        } else {
            try? line.write(to: fileURL)
        }
    }

    private func broadcast(capture: AgentBridgeCapture) {
        for listener in captureListeners.values {
            listener(capture)
        }
    }

    private func mapClaudeSocketStatus(_ raw: String) -> AgentStatus {
        switch raw {
        case "waiting_for_approval":
            return .waitingForApproval
        case "waiting_for_input":
            return .waitingForInput
        case "running_tool", "processing":
            return .runningTool
        case "compacting":
            return .compacting
        case "ended":
            return .complete
        default:
            return .thinking
        }
    }

    private func openClawBehavior(for response: String) -> String {
        let normalized = response.lowercased()
        if normalized.contains("always") || normalized.contains("bypass") {
            return "always"
        }
        if normalized.contains("deny") || normalized.contains("reject") || normalized == "n" || normalized.contains("cancel") {
            return "deny"
        }
        return "allow"
    }

    private func jsonString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func compactWhitespace(_ text: String?) -> String? {
        guard let text else { return nil }
        let parts = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func stringify(_ value: Any?) -> String {
        switch value {
        case let value as String:
            return value
        case let value as NSNumber:
            return value.stringValue
        default:
            return ""
        }
    }
}
