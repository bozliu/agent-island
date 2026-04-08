import AppKit
import SwiftUI
import AgentIslandUI

@MainActor
final class ControlPanelWindowController: NSWindowController, NSWindowDelegate {
    private let panelSize = NSSize(width: 1080, height: 760)

    init(model: AppModel) {
        let hostingController = NSHostingController(rootView: DashboardRootView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier("control-panel")
        window.title = "Agent Island"
        window.setContentSize(panelSize)
        window.minSize = NSSize(width: 940, height: 640)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.center()

        super.init(window: window)
        shouldCascadeWindows = false
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showControlPanel() {
        guard let window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
