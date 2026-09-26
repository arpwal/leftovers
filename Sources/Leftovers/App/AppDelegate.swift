import AppKit

/// Owns the app's long-lived pieces. What ⌘Q means lives in `QuitController`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: MonitorStore?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = MonitorStore()
        self.store = store
        WindowCoordinator.shared.store = store
        statusItem = StatusItemController(store: store)
        NSApp.mainMenu = MainMenu.make()
        UpdateController.shared.start()
        if !UserDefaults.standard.bool(forKey: SettingsKey.hasCompletedOnboarding) {
            WindowCoordinator.shared.showWelcome()
        }
    }

    /// Every termination request quits. ⌘Q never reaches here: the main
    /// menu routes it to `QuitController.commandQ()` instead. Guessing from
    /// `NSApp.currentEvent` was wrong: an Apple Event quit (logout, restart,
    /// an update install) leaves the last ⌘Q key event in place and was
    /// cancelled as if it were a keystroke.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }

    /// With "Quit Leftovers" selected in Settings, closing the last window quits.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppSettings.closeBehavior == .quitCompletely
    }
}

/// Quitting. ⌘Q closes the window and keeps the menu-bar item running
/// (default), or quits if Settings say so. "Quit Leftovers" in the menu bar
/// menu, logout, restart and update installs always quit.
@MainActor
enum QuitController {
    static func quitCompletely() {
        NSApp.terminate(nil)
    }

    /// The main menu's ⌘Q.
    static func commandQ() {
        if AppSettings.closeBehavior == .keepInMenuBar {
            WindowCoordinator.shared.closeAll()
        } else {
            quitCompletely()
        }
    }
}
