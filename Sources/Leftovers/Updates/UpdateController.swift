import AppKit
import Sparkle

/// Software updates via Sparkle. The only network request Leftovers makes is
/// this check against the release feed on GitHub Pages, and it can be turned
/// off in Settings. Sparkle asks on second launch whether to check automatically.
@MainActor
final class UpdateController: NSObject, SPUStandardUserDriverDelegate {
    static let shared = UpdateController()
    private var controller: SPUStandardUpdaterController?

    /// Called once from `applicationDidFinishLaunching`; never in CLI modes.
    func start() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var isAvailable: Bool { controller != nil }

    // A menu-bar app has no window to come forward, so scheduled update
    // alerts are shown gently rather than stealing focus.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }
}
