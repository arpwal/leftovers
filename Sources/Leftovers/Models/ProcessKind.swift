import Foundation

/// What sort of binary a process runs, derived purely from its executable path.
enum ProcessKind: String, Hashable {
    /// Lives inside a `.app` bundle (Slack, iTerm2, Xcode…).
    case appBundle
    /// An on-demand XPC service. launchd relaunches it when a client needs it,
    /// so killing a leaked one is recoverable — even when it ships with macOS.
    case xpcHelper
    /// A macOS binary under /System, /usr/libexec, etc.
    case systemBinary
    /// A plain command-line program (node, python, a dev server…).
    case commandLine

    private static let systemPrefixes = [
        "/System/", "/usr/bin/", "/usr/sbin/", "/usr/libexec/", "/usr/lib/",
        "/sbin/", "/bin/", "/Library/Apple/",
    ]

    static func classify(path: String) -> ProcessKind {
        // XPC check first: XPC services live inside both /System and app bundles.
        if path.contains(".xpc/Contents/MacOS/") { return .xpcHelper }
        if systemPrefixes.contains(where: path.hasPrefix) { return .systemBinary }
        if isDesktopApp(path) { return .appBundle }
        return .commandLine
    }

    /// Inside a `.app`, unless that `.app` is nested in a `.framework`:
    /// framework Python runs from `Python.framework/…/Python.app/Contents/MacOS/Python`
    /// and is an interpreter, not a desktop app. (Slack's helpers sit in
    /// `Slack.app/Contents/Frameworks/…` — the `.app` comes first, so they stay apps.)
    private static func isDesktopApp(_ path: String) -> Bool {
        guard let app = path.range(of: ".app/Contents/") else { return false }
        guard let framework = path.range(of: ".framework/") else { return true }
        return app.lowerBound < framework.lowerBound
    }

    /// True for macOS-owned binaries, including macOS's own XPC helpers.
    static func isShippedWithMacOS(path: String) -> Bool {
        systemPrefixes.contains(where: path.hasPrefix)
    }
}
