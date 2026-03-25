import Cocoa

final class ConfigManager {

    // MARK: - File location

    static let configURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/onair/config")

    // MARK: - State

    private(set) var settings: [String: String] = [:]
    var onChange: (() -> Void)?

    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?

    init() {
        reload()
        startWatching()
    }

    deinit {
        fileSource?.cancel()
        dirSource?.cancel()
    }

    // MARK: - Read

    func reload() {
        guard let content = try? String(contentsOf: Self.configURL, encoding: .utf8) else {
            if !settings.isEmpty {
                settings = [:]
                onChange?()
            }
            return
        }
        let parsed = Self.parse(content)
        guard parsed != settings else { return }
        settings = parsed
        onChange?()
    }

    private static func parse(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            // Strip optional surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            // Expand leading ~
            if value.hasPrefix("~/") {
                value = NSHomeDirectory() + String(value.dropFirst())
            }
            result[key] = value
        }
        return result
    }

    // MARK: - Open in editor

    /// Creates the file with default content if absent, then opens it with the
    /// default system handler (mirrors Ghostty's "open config" behaviour).
    func openInEditor() {
        ensureConfigExists()
        NSWorkspace.shared.open(Self.configURL)
    }

    private func ensureConfigExists() {
        let url = Self.configURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let template = """
        # OnAir Menu Bar – configuration
        # https://github.com/aamaliaa/hass-onair-webhook

        # Path to the hass-onair-webhook scripts directory (required).
        # The toolbar uses this to find toggle_meeting.sh.
        # ONAIR_SCRIPT_DIR=~/hass-onair-webhook
        """
        try? template.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - File watching (mirrors MeetingStateManager)

    private func startWatching() { watchFile() }

    private func watchFile() {
        let fd = open(Self.configURL.path, O_EVTONLY)
        guard fd != -1 else { watchDirectory(); return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let mask = self.fileSource?.data ?? []
            self.reload()
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
        let dir = Self.configURL.deletingLastPathComponent().path
        let fd = open(dir, O_EVTONLY)
        guard fd != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if FileManager.default.fileExists(atPath: Self.configURL.path) {
                self.dirSource?.cancel()
                self.dirSource = nil
                self.watchFile()
                self.reload()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        dirSource = source
    }
}
