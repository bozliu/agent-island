import AppKit

// Adapted from farouqaldori/claude-island under Apache-2.0.
@MainActor
public final class ScreenObserver: @unchecked Sendable {
    private var observer: Any?
    private let onScreenChange: @MainActor @Sendable () -> Void

    public init(onScreenChange: @escaping @MainActor @Sendable () -> Void) {
        self.onScreenChange = onScreenChange
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onScreenChange()
            }
        }
    }

    public func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
