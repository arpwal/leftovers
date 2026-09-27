import AppKit

/// Only one Leftovers runs at a time, even with copies in two folders. A
/// second launch hands off to the running one (which reopens its dashboard,
/// like clicking its Dock icon) and exits before creating a menu-bar item.
enum SingleInstance {
    static func handOffIfAlreadyRunning() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != getpid() }
        guard let running = others.first, let url = running.bundleURL else { return }
        let done = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            done.signal()
        }
        _ = done.wait(timeout: .now() + 3)
        exit(0)
    }
}
