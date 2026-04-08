import AgentCore
import Foundation
import SourceAdapters

private final class WatchedPath: @unchecked Sendable {
    let fileDescriptor: Int32
    let source: DispatchSourceFileSystemObject

    init(url: URL, callback: @escaping @Sendable () -> Void) throws {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .ENOENT)
        }
        self.fileDescriptor = descriptor
        self.source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler(handler: callback)
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
    }

    deinit {
        source.cancel()
    }
}

private struct SourceWatchRegistration: Sendable {
    let source: AgentSource
    let watcher: WatchedPath
}

public final class SourceWatchCoordinator: @unchecked Sendable {
    public static let shared = SourceWatchCoordinator()

    private let queue = DispatchQueue(label: "app.vibeisland.source-watch", qos: .utility)
    private var watched: [String: SourceWatchRegistration] = [:]
    private var debounceWorkItem: DispatchWorkItem?
    private var pendingSources: Set<AgentSource> = []
    private var onChange: (@Sendable (Set<AgentSource>) -> Void)?

    private init() {}

    public func configure(
        adapters: [any AgentSourceAdapter],
        environment: AgentEnvironment = .live(),
        onChange: @escaping @Sendable (Set<AgentSource>) -> Void
    ) {
        queue.async { [weak self] in
            self?.onChange = onChange
            self?.rebuildWatchers(adapters: adapters, environment: environment)
        }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.watched.removeAll()
            self?.pendingSources.removeAll()
            self?.onChange = nil
        }
    }

    private func rebuildWatchers(adapters: [any AgentSourceAdapter], environment: AgentEnvironment) {
        watched.removeAll()
        for adapter in adapters {
            guard let paths = try? adapter.watchPaths(in: environment) else { continue }
            for url in paths where FileManager.default.fileExists(atPath: url.path) {
                guard watched[url.path] == nil else { continue }
                if let watcher = try? WatchedPath(url: url, callback: { [weak self] in
                    self?.scheduleReloadNotification(for: adapter.source)
                }) {
                    watched[url.path] = SourceWatchRegistration(source: adapter.source, watcher: watcher)
                }
            }
        }
    }

    private func scheduleReloadNotification(for source: AgentSource) {
        pendingSources.insert(source)
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            let sources = self.pendingSources
            self.pendingSources.removeAll()
            self.onChange?(sources)
        }
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
}
