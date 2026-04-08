import AgentCore
import Foundation
import SourceAdapters

public struct SessionCoordinatorUpdate: Sendable {
    public let sessions: [AgentSession]
    public let failures: [String]

    public init(sessions: [AgentSession], failures: [String]) {
        self.sessions = sessions
        self.failures = failures
    }
}

public actor SessionCoordinator {
    private let sessionIndexStore: SessionIndexStore
    private let transports: [any AgentLiveTransport]

    private var adapters: [AgentSource: any AgentSourceAdapter]
    private var eventsBySource: [AgentSource: [AgentEvent]] = [:]
    private var enabledSources: Set<AgentSource> = []
    private var environment: AgentEnvironment = .live()
    private var updateHandler: (@Sendable (SessionCoordinatorUpdate) -> Void)?
    private var pendingSources: Set<AgentSource> = []
    private var debounceTask: Task<Void, Never>?

    public init(
        adapters: [any AgentSourceAdapter],
        sessionIndexStore: SessionIndexStore = SessionIndexStore(),
        transports: [any AgentLiveTransport] = [
            HookSocketLiveTransport(),
            SourceWatchLiveTransport(),
        ]
    ) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.source, $0) })
        self.sessionIndexStore = sessionIndexStore
        self.transports = transports
    }

    public func start(
        enabledSources: Set<AgentSource>,
        environment: AgentEnvironment,
        onUpdate: @escaping @Sendable (SessionCoordinatorUpdate) -> Void
    ) async -> SessionCoordinatorUpdate {
        self.enabledSources = enabledSources
        self.environment = environment
        updateHandler = onUpdate
        configureTransports()
        return await reloadAll()
    }

    public func replaceAdapters(_ adapters: [any AgentSourceAdapter]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.source, $0) })
        configureTransports()
    }

    public func updateEnabledSources(
        _ enabledSources: Set<AgentSource>,
        environment: AgentEnvironment
    ) async -> SessionCoordinatorUpdate {
        self.enabledSources = enabledSources
        self.environment = environment
        eventsBySource = eventsBySource.filter { enabledSources.contains($0.key) }
        configureTransports()
        return await reloadAll()
    }

    public func reloadAll() async -> SessionCoordinatorUpdate {
        await reload(sources: enabledSources)
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        pendingSources.removeAll()
        updateHandler = nil
        for transport in transports {
            transport.stop()
        }
    }

    private func configureTransports() {
        let context = AgentLiveTransportContext(
            adapters: activeAdapters(),
            environment: environment
        )
        let coordinator = self
        for transport in transports {
            transport.start(context: context) { event in
                Task {
                    await coordinator.handleTransportEvent(event)
                }
            }
        }
    }

    private func handleTransportEvent(_ event: AgentLiveTransportEvent) async {
        switch event {
        case .capture(let capture):
            guard enabledSources.contains(capture.source) else { return }
            scheduleReload(for: [capture.source])
        case .sourcesChanged(let sources):
            let sources = sources.intersection(enabledSources)
            guard sources.isEmpty == false else { return }
            scheduleReload(for: sources)
        }
    }

    private func scheduleReload(for sources: Set<AgentSource>) {
        pendingSources.formUnion(sources)
        guard debounceTask == nil else { return }

        let coordinator = self
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await coordinator.flushPendingReload()
        }
    }

    private func flushPendingReload() async {
        let sources = pendingSources
        pendingSources.removeAll()
        debounceTask = nil
        guard sources.isEmpty == false else { return }

        let update = await reload(sources: sources)
        updateHandler?(update)
    }

    private func reload(sources: Set<AgentSource>) async -> SessionCoordinatorUpdate {
        guard sources.isEmpty == false else {
            let sessions = await sessionIndexStore.replace(with: flattenedEvents())
            return SessionCoordinatorUpdate(sessions: sessions, failures: [])
        }

        var failures: [String] = []
        for source in sources.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard enabledSources.contains(source), let adapter = adapters[source] else {
                eventsBySource[source] = []
                continue
            }

            do {
                let discovered = try await adapter.discoverSessions(in: environment)
                var sourceEvents: [AgentEvent] = []
                for session in discovered {
                    do {
                        sourceEvents.append(contentsOf: try await adapter.loadEvents(for: session, in: environment))
                    } catch {
                        failures.append("\(source.rawValue): \(session.sessionId): \(error.localizedDescription)")
                    }
                }
                eventsBySource[source] = sourceEvents
            } catch {
                eventsBySource[source] = []
                failures.append("\(source.rawValue): \(error.localizedDescription)")
            }
        }

        let sessions = await sessionIndexStore.replace(with: flattenedEvents())
        return SessionCoordinatorUpdate(sessions: sessions, failures: failures)
    }

    private func flattenedEvents() -> [AgentEvent] {
        enabledSources
            .sorted(by: { $0.rawValue < $1.rawValue })
            .flatMap { eventsBySource[$0] ?? [] }
    }

    private func activeAdapters() -> [any AgentSourceAdapter] {
        enabledSources
            .compactMap { adapters[$0] }
            .sorted { $0.source.rawValue < $1.source.rawValue }
    }
}
