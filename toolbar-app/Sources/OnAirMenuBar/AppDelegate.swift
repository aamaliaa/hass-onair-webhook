import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let stateManager = MeetingStateManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // No Dock icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        stateManager.onChange = { [weak self] in
            DispatchQueue.main.async { self?.refreshUI() }
        }
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
        // Template images adapt to dark/light menu bar; non-template preserves colour
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
}
