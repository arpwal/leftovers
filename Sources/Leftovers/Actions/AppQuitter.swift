import AppKit

/// Quits a desktop app the normal way (the same Quit event as ⌘Q), so it can
/// save work and ask about unsaved documents. Never force-quits.
@MainActor
enum AppQuitter {
    /// macOS's own background apps (Finder, Spotlight, Control Center…) live
    /// here and are never offered a Quit button. Apps in /System/Applications
    /// (Notes, Music…) are ordinary apps and can be quit.
    private static let protectedPrefix = "/System/Library/"
    private static let waitForExit: Duration = .seconds(5)

    static func runningApps(for group: AppGroup) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.bundleURL?.path == group.bundlePath && $0.processIdentifier != getpid()
        }
    }

    static func canQuit(_ group: AppGroup, protectedNames: Set<String>) -> Bool {
        guard !group.bundlePath.hasPrefix(protectedPrefix), !protectedNames.contains(group.name) else { return false }
        return !runningApps(for: group).isEmpty
    }

    /// Returns a message for the status line.
    static func quit(_ group: AppGroup) async -> String {
        let apps = runningApps(for: group)
        guard !apps.isEmpty else { return "\(group.name) is not running" }
        apps.forEach { $0.terminate() }
        let deadline = ContinuousClock.now + waitForExit
        while ContinuousClock.now < deadline, apps.contains(where: { !$0.isTerminated }) {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return apps.allSatisfy(\.isTerminated)
            ? "\(group.name) quit"
            : "\(group.name) is still open. It may be asking about unsaved work."
    }
}
