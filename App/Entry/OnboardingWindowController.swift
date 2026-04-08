import AppKit
import Combine
import SwiftUI
import AgentIslandUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []
    var onClose: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        NSLog("[AgentIsland] OnboardingWindowController.init")

        let hostingController = NSHostingController(rootView: OnboardingView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier("onboarding-window")
        window.title = "Agent Island"
        window.setContentSize(NSSize(width: 1180, height: 760))
        window.minSize = NSSize(width: 1080, height: 720)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.center()

        super.init(window: window)

        shouldCascadeWindows = false
        self.window?.delegate = self
        self.window?.orderOut(nil)
        bindModel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showOnboarding() {
        NSLog("[AgentIsland] OnboardingWindowController.showOnboarding")
        guard let window else { return }
        window.contentViewController = NSHostingController(rootView: OnboardingView(model: model))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model.dismissOnboarding()
        sender.orderOut(nil)
        onClose?()
        return false
    }

    private func bindModel() {
        model.$showOnboarding
            .dropFirst()
            .sink { [weak self] shouldShow in
                Task { @MainActor in
                    if shouldShow {
                        self?.showOnboarding()
                    } else {
                        self?.window?.orderOut(nil)
                        self?.onClose?()
                    }
                }
            }
            .store(in: &cancellables)
    }
}
