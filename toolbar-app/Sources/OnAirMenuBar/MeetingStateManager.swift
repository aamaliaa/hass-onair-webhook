import Foundation

enum MeetingState: Equatable {
    case active
    case inactive
    case unknown

    var label: String {
        switch self {
        case .active:   return "● On Air"
        case .inactive: return "○ Not in Meeting"
        case .unknown:  return "? Status Unknown"
        }
    }
}

final class MeetingStateManager {
    private(set) var state: MeetingState = .unknown
    var onChange: (() -> Void)?

    private let config: ConfigManager
    private let stateFile = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".meeting_listener_state")
    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?

    init(config: ConfigManager) {
        self.config = config
        reloadState()
        startWatching()
    }

    deinit {
        fileSource?.cancel()
        dirSource?.cancel()
    }

    // MARK: - State

    func reloadState() {
        guard let raw = try? String(contentsOf: stateFile, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            update(.unknown)
            return
        }
        // Treat stale state (>30 s old) as unknown — mirrors listener.sh logic
        if let attrs = try? FileManager.default.attributesOfItem(atPath: stateFile.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) > 30 {
            update(.unknown)
            return
        }
        update(raw == "ACTIVE" ? .active : .inactive)
    }

    private func update(_ newState: MeetingState) {
        guard newState != state else { return }
        state = newState
        onChange?()
    }

    // MARK: - Toggle

    /// True when toggle_meeting.sh can be located. Used by AppDelegate to show
    /// a "Setup Required" warning when the user hasn't configured ONAIR_SCRIPT_DIR.
    var isConfigured: Bool { findToggleScript() != nil }

    func toggle() {
        guard let scriptPath = findToggleScript() else {
            NSLog("OnAirMenuBar: toggle_meeting.sh not found — set ONAIR_SCRIPT_DIR in ~/.config/onair/config")
            return
        }
        // Snapshot config values now so the background thread doesn't race with a reload
        let configEnv = config.settings.filter { ["HA_WEBHOOK_URL", "HA_BASE_URL"].contains($0.key) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [scriptPath]
            // Config-file values override the inherited environment; toggle_meeting.sh
            // falls back to sourcing .env for anything still unset.
            var env = ProcessInfo.processInfo.environment
            for (key, value) in configEnv { env[key] = value }
            task.environment = env
            try? task.run()
            task.waitUntilExit()
            DispatchQueue.main.async { self?.reloadState() }
        }
    }

    private func findToggleScript() -> String? {
        let fm = FileManager.default
        let home = NSHomeDirectory()

        // 1. Config file setting (highest priority — user-editable)
        if let dir = config.settings["ONAIR_SCRIPT_DIR"] {
            let path = (dir as NSString).appendingPathComponent("toggle_meeting.sh")
            if fm.isExecutableFile(atPath: path) { return path }
        }

        // 2. Environment variable override (e.g. set at launch time)
        if let dir = ProcessInfo.processInfo.environment["ONAIR_SCRIPT_DIR"] {
            let path = (dir as NSString).appendingPathComponent("toggle_meeting.sh")
            if fm.isExecutableFile(atPath: path) { return path }
        }

        // 3. Common install locations
        let candidates = [
            "\(home)/.hass-onair-webhook/toggle_meeting.sh",
            "\(home)/hass-onair-webhook/toggle_meeting.sh",
            "\(home)/Projects/hass-onair-webhook/toggle_meeting.sh",
            "\(home)/Developer/hass-onair-webhook/toggle_meeting.sh",
        ]
        if let found = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) {
            return found
        }

        // 3. Sibling of the .app bundle (for when app is placed next to the repo)
        if let bundlePath = Bundle.main.bundlePath as String? {
            let appDir = URL(fileURLWithPath: bundlePath).deletingLastPathComponent().path
            let path = (appDir as NSString).appendingPathComponent("toggle_meeting.sh")
            if fm.isExecutableFile(atPath: path) { return path }
        }

        return nil
    }

    // MARK: - File watching

    private func startWatching() {
        watchFile()
    }

    private func watchFile() {
        let fd = open(stateFile.path, O_EVTONLY)
        guard fd != -1 else {
            watchDirectory()  // File doesn't exist yet; watch for creation
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let mask = self.fileSource?.data ?? []
            self.reloadState()
            if mask.contains(.delete) || mask.contains(.rename) {
                self.fileSource?.cancel()
                self.fileSource = nil
                self.watchDirectory()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileSource = source
    }

    private func watchDirectory() {
        let fd = open(NSHomeDirectory(), O_EVTONLY)
        guard fd != -1 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if FileManager.default.fileExists(atPath: self.stateFile.path) {
                self.dirSource?.cancel()
                self.dirSource = nil
                self.watchFile()
                self.reloadState()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        dirSource = source
    }
}
