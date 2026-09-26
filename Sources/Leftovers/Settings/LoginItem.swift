import ServiceManagement

/// "Open at login", backed by the system's Login Items (SMAppService).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message to show, or nil on success.
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return "macOS didn't allow this: \(error.localizedDescription)"
        }
    }
}
