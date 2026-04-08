import AppKit
import SwiftUI
import AgentIslandUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    init(model: AppModel) {
        NSLog("[AgentIsland] SettingsWindowController.init")
        let hostingController = NSHostingController(rootView: SettingsWindowView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier("settings-window")
        window.title = "Agent Island"
        window.setContentSize(NSSize(width: 980, height: 720))
        window.minSize = NSSize(width: 920, height: 640)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.center()

        super.init(window: window)
        shouldCascadeWindows = false
        self.window?.delegate = self
        self.window?.orderOut(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettings() {
        NSLog("[AgentIsland] SettingsWindowController.showSettings")
        guard let window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        onClose?()
        return false
    }
}
