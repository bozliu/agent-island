import AppKit
import ClaudeIslandRuntime
import Combine
import SwiftUI
import AgentIslandUI

@MainActor
private final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var hitTestRect: () -> CGRect = { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hitTestRect().contains(point) else { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
private final class IslandHostController: NSViewController {
    private let model: AppModel
    private var hostingView: PassThroughHostingView<AnyView>!

    init(model: AppModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = rootView()

        let hostingView = PassThroughHostingView(rootView: root)
        hostingView.hitTestRect = { [weak hostingView] in
            hostingView?.bounds ?? .zero
        }
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.hostingView = hostingView
        self.view = hostingView
    }

    func refreshLayout() {
        hostingView.rootView = rootView()
    }

    private func rootView() -> AnyView {
        AnyView(
            NotchIslandView(model: self.model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.clear)
        )
    }
}

@MainActor
final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private var cancellables: Set<AnyCancellable> = []
    private var screenObserver: ScreenObserver?
    private let hostController: IslandHostController

    init(model: AppModel) {
        self.model = model
        self.hostController = IslandHostController(model: model)

        let initialScreen = IslandScreenResolver.resolve(displayTarget: model.displayTarget) ?? NSScreen.vibeIslandBuiltin ?? NSScreen.main ?? NSScreen.screens.first
        let initialFrame = DashboardWindowController.windowFrame(
            for: model,
            on: initialScreen ?? NSScreen.main ?? NSScreen.screens.first
        )
        let panel = NotchPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("island-panel")
        panel.title = "Agent Island"
        panel.contentViewController = hostController
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = NSWindow.AnimationBehavior.utilityWindow
        panel.acceptsMouseMovedEvents = true

        super.init(window: panel)

        shouldCascadeWindows = false
        window?.delegate = self
        screenObserver = ScreenObserver { [weak self] in
            Task { @MainActor in
                self?.reposition(animated: false)
            }
        }
        bindWindowLifecycle()
        reposition(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showDashboard(activate: Bool = true) {
        guard let window else { return }
        model.expandIsland()
        present(window: window, animated: true, activate: activate)
    }

    func showCompactIsland(activate: Bool = false) {
        guard let window else { return }
        model.collapseIsland()
        present(window: window, animated: false, activate: activate)
    }

    func hide() {
        window?.orderOut(nil)
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model.collapseIsland()
        sender.orderOut(nil)
        return false
    }

    private func bindWindowLifecycle() {
        model.$islandExpanded
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)

        model.$dashboardMode
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)

        model.$selectedSessionID
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reposition(animated: true)
                }
            }
            .store(in: &cancellables)

        model.$sessions
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.synchronizeVisibility()
                    self?.reposition(animated: false)
                }
            }
            .store(in: &cancellables)

        model.$autoHideWhenIdle
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.synchronizeVisibility()
                }
            }
            .store(in: &cancellables)

        model.$showOnboarding
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.synchronizeVisibility()
                }
            }
            .store(in: &cancellables)

        EventMonitors.shared.mouseDown
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleCompactIslandClick(event)
            }
            .store(in: &cancellables)
    }

    private func reposition(animated: Bool) {
        guard let window else { return }

        let screen = IslandScreenResolver.resolve(displayTarget: model.displayTarget) ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let targetFrame = Self.windowFrame(for: model, on: screen)
        if animated, window.isVisible {
            window.animator().setFrame(targetFrame, display: true)
        } else {
            window.setFrame(targetFrame, display: true)
        }
        hostController.refreshLayout()
    }

    private func present(window: NSWindow, animated: Bool, activate: Bool) {
        reposition(animated: animated)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    private func synchronizeVisibility() {
        guard let window else { return }

        if model.showOnboarding {
            window.orderOut(nil)
            return
        }

        let shouldHideForIdle = model.autoHideWhenIdle && model.monitoredSessions.isEmpty
        if shouldHideForIdle {
            window.orderOut(nil)
            return
        }

        guard window.isVisible == false else { return }

        if model.islandExpanded {
            showDashboard(activate: false)
        } else {
            showCompactIsland(activate: false)
        }
    }

    private static func windowFrame(for model: AppModel, on screen: NSScreen?) -> CGRect {
        guard let screen else {
            return .zero
        }

        let size = preferredSize(for: model, on: screen)
        let topInset = contentTopInset(for: model, on: screen, size: size)
        return CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - topInset - size.height,
            width: size.width,
            height: size.height
        )
        .integral
    }

    private static func contentTopInset(for model: AppModel, on screen: NSScreen, size: CGSize) -> CGFloat {
        let topUnsafeInset = IslandScreenResolver.topUnsafeInset(on: screen)
        if model.islandExpanded {
            if screen.vibeIslandHasPhysicalNotch {
                return 0
            }
            return max(10, topUnsafeInset - 12)
        }
        if screen.vibeIslandHasPhysicalNotch {
            return max(0, topUnsafeInset - size.height)
        }
        return 8
    }

    private static func preferredSize(for model: AppModel, on screen: NSScreen) -> CGSize {
        if model.islandExpanded {
            return CGSize(width: 1080, height: min(max(model.maxPanelHeight, 420), 720))
        }

        let compactWidth = max(
            model.layoutMode == .clean ? 304.0 : 372.0,
            screen.vibeIslandHasPhysicalNotch ? screen.vibeIslandNotchSize.width + 96 : 0,
            screen.vibeIslandHasPhysicalNotch ? (model.layoutMode == .clean ? 360.0 : 420.0) : 0
        )

        if screen.vibeIslandHasPhysicalNotch {
            let compactHeight = max(32, min(model.layoutMode == .clean ? 40 : 46, screen.vibeIslandNotchSize.height))
            return CGSize(width: compactWidth, height: compactHeight)
        }

        return CGSize(width: compactWidth, height: model.layoutMode == .clean ? 40 : 46)
    }

    private func handleCompactIslandClick(_ event: NSEvent) {
        guard model.islandExpanded == false else { return }
        guard model.showOnboarding == false else { return }
        guard let window, window.isVisible else { return }

        let screenPoint: CGPoint
        if let eventWindow = event.window {
            screenPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
        } else {
            screenPoint = event.locationInWindow
        }

        guard window.frame.contains(screenPoint) else { return }
        showDashboard(activate: false)
    }
}

private enum IslandScreenResolver {
    static func resolve(displayTarget: DisplayTarget) -> NSScreen? {
        switch displayTarget {
        case .automatic:
            return builtInScreen() ?? NSScreen.main ?? NSScreen.screens.first
        case .builtIn:
            return builtInScreen() ?? NSScreen.main ?? NSScreen.screens.first
        case .main:
            return NSScreen.main ?? NSScreen.screens.first
        }
    }

    static func notchCenterX(on screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            let left = screen.auxiliaryTopLeftArea
            let right = screen.auxiliaryTopRightArea

            if let left, let right, left.isEmpty == false, right.isEmpty == false {
                return (left.maxX + right.minX) / 2
            }
        }

        return screen.frame.midX
    }

    static func notchBottomY(on screen: NSScreen) -> CGFloat {
        screen.vibeIslandNotchBottomY
    }

    static func topUnsafeInset(on screen: NSScreen) -> CGFloat {
        screen.vibeIslandTopUnsafeInset
    }

    private static func builtInScreen() -> NSScreen? {
        NSScreen.vibeIslandBuiltin ?? NSScreen.screens.first {
            $0.localizedName.localizedCaseInsensitiveContains("built")
        }
    }
}
