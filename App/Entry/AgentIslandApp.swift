import AppKit
import Combine
import AgentIslandUI

@MainActor
private let sharedAppModel = AppModel()

@MainActor
private final class LaunchCoordinator: NSObject, NSApplicationDelegate {
    private var dashboardWindowController: DashboardWindowController?
    private var statusItemController: StatusItemController?
    private var onboardingWindowController: OnboardingWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AgentIsland] applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        let dashboardWindowController = DashboardWindowController(model: sharedAppModel)
        self.dashboardWindowController = dashboardWindowController
        self.statusItemController = StatusItemController(model: sharedAppModel, dashboardWindowController: dashboardWindowController)

        NotificationCenter.default.publisher(for: .vibeIslandOpenSettings)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.showSettings()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .vibeIslandOpenOnboarding)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.showOnboarding()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("vibeIslandNeedsAttention"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.dashboardWindowController?.showDashboard(activate: true)
                }
            }
            .store(in: &cancellables)

        hideUnexpectedWindows()
        if sharedAppModel.showOnboarding {
            showOnboarding()
        } else if sharedAppModel.autoHideWhenIdle == false {
            dashboardWindowController.showCompactIsland()
        }

        Task {
            await sharedAppModel.performInitialLoad()
            hideUnexpectedWindows()
            guard sharedAppModel.showOnboarding == false else { return }
            guard sharedAppModel.autoHideWhenIdle == false || sharedAppModel.monitoredSessions.isEmpty == false else { return }

            if sharedAppModel.attentionSessions.isEmpty {
                dashboardWindowController.showCompactIsland()
            } else {
                dashboardWindowController.showDashboard(activate: false)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            dashboardWindowController?.showDashboard()
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard sharedAppModel.showOnboarding == false else { return }
        guard sharedAppModel.autoHideWhenIdle == false || sharedAppModel.monitoredSessions.isEmpty == false else { return }
        dashboardWindowController?.showCompactIsland()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await sharedAppModel.shutdown()
        }
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    private func hideUnexpectedWindows() {
        let allowedIdentifiers: Set<String> = [
            "island-panel",
            "onboarding-window",
            "settings-window",
        ]

        for window in NSApp.windows {
            NSLog("[AgentIsland] window: \(window.title) identifier: \(window.identifier?.rawValue ?? "nil")")
            guard let identifier = window.identifier?.rawValue else {
                window.orderOut(nil)
                continue
            }

            if allowedIdentifiers.contains(identifier) == false {
                window.orderOut(nil)
            }
        }
    }

    private func showSettings() {
        NSLog("[AgentIsland] showSettings")
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(model: sharedAppModel)
            settingsWindowController?.onClose = { [weak self] in
                Task { @MainActor in
                    self?.restoreDashboardIfNeeded()
                }
            }
        }
        NSApp.setActivationPolicy(.regular)
        dashboardWindowController?.hide()
        settingsWindowController?.showSettings()
    }

    private func showOnboarding() {
        NSLog("[AgentIsland] showOnboarding")
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(model: sharedAppModel)
            onboardingWindowController?.onClose = { [weak self] in
                Task { @MainActor in
                    self?.restoreDashboardIfNeeded()
                }
            }
        }
        NSApp.setActivationPolicy(.regular)
        dashboardWindowController?.hide()
        onboardingWindowController?.showOnboarding()
    }

    private func restoreDashboardIfNeeded() {
        NSApp.setActivationPolicy(.accessory)
        guard sharedAppModel.showOnboarding == false else { return }
        guard sharedAppModel.autoHideWhenIdle == false || sharedAppModel.monitoredSessions.isEmpty == false else { return }

        if sharedAppModel.attentionSessions.isEmpty {
            dashboardWindowController?.showCompactIsland(activate: false)
        } else {
            dashboardWindowController?.showDashboard(activate: false)
        }
    }
}

@main
enum AgentIslandAppMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = LaunchCoordinator()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        _ = delegate
    }
}
