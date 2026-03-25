import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let configManager = ConfigManager()
    private lazy var stateManager = MeetingStateManager(config: configManager)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // No Dock icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let refresh = { [weak self] in DispatchQueue.main.async { self?.refreshUI() } }
        stateManager.onChange = refresh
        configManager.onChange = refresh

        refreshUI()
    }

    // MARK: - UI

    private func refreshUI() {
        let state = stateManager.state
        updateButton(state)
        statusItem.menu = buildMenu(state)
    }

    private func updateButton(_ state: MeetingState) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        switch state {
        case .active:   symbolName = "video.fill"
        case .inactive: symbolName = "video.slash"
        case .unknown:  symbolName = "questionmark.circle"
        }

        var config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        if state == .active {
            // Tint red when on-air; not a template so the colour is preserved
            config = config.applying(.init(paletteColors: [.systemRed]))
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: state.label)?
            .withSymbolConfiguration(config)
        button.image?.isTemplate = (state != .active)
    }

    private func buildMenu(_ state: MeetingState) -> NSMenu {
        let menu = NSMenu()

        let statusLabel = NSMenuItem(title: state.label, action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: "Toggle Meeting Status",
            action: #selector(toggleMeeting),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        // ── Configuration ─────────────────────────────────────────────────────
        let openCfg = NSMenuItem(
            title: "Open Configuration",
            action: #selector(openConfiguration),
            keyEquivalent: ","          // Cmd+,  (standard macOS preferences shortcut)
        )
        openCfg.target = self
        menu.addItem(openCfg)

        let reloadCfg = NSMenuItem(
            title: "Reload Configuration",
            action: #selector(reloadConfiguration),
            keyEquivalent: "r"          // Cmd+R
        )
        reloadCfg.target = self
        menu.addItem(reloadCfg)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    // MARK: - Actions

    @objc private func toggleMeeting() {
        stateManager.toggle()
    }

    @objc private func openConfiguration() {
        configManager.openInEditor()
    }

    @objc private func reloadConfiguration() {
        configManager.reload()
    }
}
