import AppKit
import Combine
import AgentIslandUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private static let visibleModes: [DashboardMode] = [.monitor, .approve, .ask]
    private let model: AppModel
    private weak var dashboardWindowController: DashboardWindowController?
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel, dashboardWindowController: DashboardWindowController) {
        self.model = model
        self.dashboardWindowController = dashboardWindowController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureButton()
        configureMenu()
        observeModel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.toolTip = "Agent Island"
        button.imagePosition = .imageLeading
        button.font = .monospacedSystemFont(ofSize: 11, weight: .black)
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshButtonAppearance()
    }

    private func configureMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
    }

    private func statusImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "extension-icon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            return image
        }

        let fallback = NSImage(systemSymbolName: "capsule.portrait.fill", accessibilityDescription: "Agent Island")
        fallback?.size = NSSize(width: 16, height: 16)
        return fallback
    }

    private func observeModel() {
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.refreshButtonAppearance()
            }
            .store(in: &cancellables)
    }

    private func refreshButtonAppearance() {
        guard let button = statusItem.button else { return }
        button.image = statusImage()
        let attentionCount = model.attentionSessions.count
        button.title = attentionCount > 0 ? " \(attentionCount)" : ""
        button.contentTintColor = attentionCount > 0 ? .systemOrange : .labelColor
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            toggleDashboard()
            return
        }

        let isContextClick = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if isContextClick {
            showContextMenu()
        } else {
            toggleDashboard()
        }
    }

    private func toggleDashboard() {
        if dashboardWindowController?.isVisible == true, model.showOnboarding == false {
            dashboardWindowController?.hide()
        } else {
            dashboardWindowController?.showDashboard()
        }
    }

    private func showContextMenu() {
        rebuildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let openItem = NSMenuItem(
            title: "Open Island",
            action: #selector(openDashboard),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(
            title: "Refresh Sessions",
            action: #selector(refreshSessions),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        for mode in Self.visibleModes {
            let count = count(for: mode)
            let item = NSMenuItem(
                title: "\(mode.title) (\(count))",
                action: #selector(selectMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = model.dashboardMode == mode ? NSControl.StateValue.on : NSControl.StateValue.off
            menu.addItem(item)
        }

        if !model.attentionSessions.isEmpty {
            menu.addItem(.separator())
            for session in model.attentionSessions.prefix(4) {
                let item = NSMenuItem(
                    title: session.title,
                    action: #selector(selectSession(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = session.id
                menu.addItem(item)
            }
        }

        if let diagnosticsMessage = model.diagnosticsMessage, !diagnosticsMessage.isEmpty {
            menu.addItem(.separator())
            let diagnosticsItem = NSMenuItem(title: diagnosticsMessage, action: nil, keyEquivalent: "")
            diagnosticsItem.isEnabled = false
            menu.addItem(diagnosticsItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Agent Island",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc
    private func openDashboard() {
        dashboardWindowController?.showDashboard()
    }

    @objc
    private func refreshSessions() {
        Task {
            await model.reloadLiveData()
        }
    }

    @objc
    private func openSettings() {
        NotificationCenter.default.post(name: .vibeIslandOpenSettings, object: nil)
    }

    @objc
    private func selectMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = DashboardMode(rawValue: rawValue)
        else {
            return
        }

        model.setDashboardMode(mode)
        dashboardWindowController?.showDashboard()
    }

    @objc
    private func selectSession(_ sender: NSMenuItem) {
        guard let sessionID = sender.representedObject as? String else { return }
        if let session = model.sessions.first(where: { $0.id == sessionID }) {
            model.select(session)
        }
        dashboardWindowController?.showDashboard()
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func count(for mode: DashboardMode) -> Int {
        model.sessions(for: mode).count
    }
}
