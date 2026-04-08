import AppKit

// Adapted from farouqaldori/claude-island under Apache-2.0.
public class NotchPanel: NSPanel {
    public override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        level = .mainMenu + 3
        allowsToolTipsWhenApplicationIsInactive = true
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .leftMouseUp ||
            event.type == .rightMouseDown || event.type == .rightMouseUp {
            let locationInWindow = event.locationInWindow
            if let contentView = contentView,
               contentView.hitTest(locationInWindow) == nil {
                let screenLocation = convertPoint(toScreen: locationInWindow)
                ignoresMouseEvents = true
                DispatchQueue.main.async { [weak self] in
                    self?.repostMouseEvent(event, at: screenLocation)
                    self?.ignoresMouseEvents = false
                }
                return
            }
        }

        super.sendEvent(event)
    }

    private func repostMouseEvent(_ event: NSEvent, at screenLocation: NSPoint) {
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(screenLocation) }) ?? self.screen ?? NSScreen.main
        guard let screen = targetScreen else { return }
        let cgPoint = CGPoint(
            x: screenLocation.x,
            y: screen.frame.maxY - screenLocation.y
        )

        let mouseType: CGEventType
        switch event.type {
        case .leftMouseDown: mouseType = .leftMouseDown
        case .leftMouseUp: mouseType = .leftMouseUp
        case .rightMouseDown: mouseType = .rightMouseDown
        case .rightMouseUp: mouseType = .rightMouseUp
        default: return
        }

        let mouseButton: CGMouseButton = event.type == .rightMouseDown || event.type == .rightMouseUp ? .right : .left

        if let cgEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseType,
            mouseCursorPosition: cgPoint,
            mouseButton: mouseButton
        ) {
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}
