import Darwin
import Foundation

/// Decides which processes must never be killed. Evaluated BEFORE leak
/// detection, so a protected process can never become a kill candidate.
struct ProtectionPolicy {
    let userProtectedNames: Set<String>
    private let currentUid = getuid()
    private let selfPid = getpid()

    /// User-owned processes macOS needs to keep your session alive.
    /// Several are relaunched automatically, but killing them still flickers
    /// the UI or drops state, so they are off-limits.
    static let coreNames: Set<String> = [
        "WindowServer", "loginwindow", "Dock", "Finder", "SystemUIServer",
        "ControlCenter", "NotificationCenter", "WindowManager", "Spotlight",
        "launchd", "kernel_task", "cfprefsd", "distnoted", "coreaudiod",
        "universalaccessd", "sharingd", "tccd", "secd", "trustd", "lsd",
        "usernoted", "pboard", "UserEventAgent", "coreservicesd", "mds",
        "mds_stores", "mdworker_shared", "talagentd", "TextInputMenuAgent",
        "AirPlayUIAgent", "WallpaperAgent", "useractivityd", "rapportd",
    ]

    /// Absolute protection, independent of any leak signal.
    func hardProtection(for snapshot: ProcessSnapshot) -> ProtectionReason? {
        if snapshot.pid == selfPid { return .selfProcess }
        if snapshot.pid <= 1 || snapshot.uid != currentUid { return .otherUser }
        if Self.coreNames.contains(snapshot.name) { return .coreSystem }
        if userProtectedNames.contains(snapshot.name) { return .userProtected }
        return nil
    }

    /// macOS binaries are protected unless they are on-demand XPC helpers,
    /// which launchd relaunches — those may only be killed when hoarding.
    func isSystemOwned(_ snapshot: ProcessSnapshot) -> Bool {
        ProcessKind.isShippedWithMacOS(path: snapshot.executablePath)
    }
}
