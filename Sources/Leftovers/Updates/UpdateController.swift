import AppKit
import Sparkle

/// Software updates via Sparkle. The only network request Leftovers makes is
/// this check against the release feed on GitHub Pages, and it can be turned
/// off in Settings. Sparkle asks on second launch whether to check automatically.
@MainActor
final class UpdateController: NSObject, ObservableObject, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {
    static let shared = UpdateController()
    /// A version that's downloaded or found and waiting for the user.
    @Published private(set) var pendingVersion: String?
    private var controller: SPUStandardUpdaterController?

    /// Called once from `applicationDidFinishLaunching`; never in CLI modes.
    func start() {
        UpdateNotifier.shared.start()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
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

    // Gentle reminders: a scheduled check that finds an update while you're
    // busy elsewhere posts a notification instead of opening a window.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                                          andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                               state: SPUUserUpdateState) {
        let version = update.displayVersionString
        Task { @MainActor in
            self.pendingVersion = version
            if !handleShowingUpdate { UpdateNotifier.shared.notify(version: version) }
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in UpdateNotifier.shared.clear() }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in self.pendingVersion = nil }
    }

    // Failures go to ~/Library/Logs/Leftovers/updates.log. "No update" isn't one.
    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let code = (error as NSError).code
        guard code != Int(SUError.noUpdateError.rawValue) else { return }
        UpdateLog.record("update aborted (\(code)): \(error.localizedDescription)")
    }

    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        guard let error, (error as NSError).code != Int(SUError.noUpdateError.rawValue) else { return }
        UpdateLog.record("update cycle failed (\((error as NSError).code)): \(error.localizedDescription)")
    }
}
