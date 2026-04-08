import AgentCore
import Foundation
import SourceAdapters

public enum AgentLiveTransportEvent: Sendable {
    case capture(AgentBridgeCapture)
    case sourcesChanged(Set<AgentSource>)
}

public struct AgentLiveTransportContext: Sendable {
    public let adapters: [any AgentSourceAdapter]
    public let environment: AgentEnvironment

    public init(adapters: [any AgentSourceAdapter], environment: AgentEnvironment) {
        self.adapters = adapters
        self.environment = environment
    }
}

public protocol AgentLiveTransport: AnyObject, Sendable {
    var name: String { get }
    func start(
        context: AgentLiveTransportContext,
        emit: @escaping @Sendable (AgentLiveTransportEvent) -> Void
    )
    func update(context: AgentLiveTransportContext)
    func stop()
}

public final class HookSocketLiveTransport: AgentLiveTransport, @unchecked Sendable {
    public let name = "hook-socket"

    private var listenerID: UUID?
    private var emit: (@Sendable (AgentLiveTransportEvent) -> Void)?

    public init() {}

    public func start(
        context: AgentLiveTransportContext,
        emit: @escaping @Sendable (AgentLiveTransportEvent) -> Void
    ) {
        self.emit = emit
        if listenerID == nil {
            listenerID = ClaudeHookTransport.shared.addCaptureListener { [weak self] capture in
                self?.emit?(.capture(capture))
            }
        }
        ClaudeHookTransport.shared.start()
    }

    public func update(context: AgentLiveTransportContext) {}

    public func stop() {
        if let listenerID {
            ClaudeHookTransport.shared.removeCaptureListener(listenerID)
            self.listenerID = nil
        }
        emit = nil
        ClaudeHookTransport.shared.stop()
    }
}

public final class SourceWatchLiveTransport: AgentLiveTransport, @unchecked Sendable {
    public let name = "source-watch"

    private let coordinator: SourceWatchCoordinator
    private var emit: (@Sendable (AgentLiveTransportEvent) -> Void)?
    private var currentContext: AgentLiveTransportContext?

    public init(coordinator: SourceWatchCoordinator = .shared) {
        self.coordinator = coordinator
    }

    public func start(
        context: AgentLiveTransportContext,
        emit: @escaping @Sendable (AgentLiveTransportEvent) -> Void
    ) {
        self.emit = emit
        currentContext = context
        coordinator.configure(adapters: context.adapters, environment: context.environment) { [weak self] sources in
            self?.emit?(.sourcesChanged(sources))
        }
    }

    public func update(context: AgentLiveTransportContext) {
        currentContext = context
        guard let emit else { return }
        start(context: context, emit: emit)
    }

    public func stop() {
        currentContext = nil
        emit = nil
        coordinator.stop()
    }
}
