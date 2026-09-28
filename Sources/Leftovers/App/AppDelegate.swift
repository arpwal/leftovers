import AppKit

/// Owns the app's long-lived pieces. What ⌘Q means lives in `QuitController`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store: MonitorStore
    private var statusItem: StatusItemController?

    init(store: MonitorStore) {
        self.store = store
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupTrace.mark("did finish launching")
        WindowCoordinator.shared.store = store
        statusItem = StatusItemController(store: store)
        NSApp.mainMenu = MainMenu.make()
        StartupTrace.mark("menu bar item ready")
        showFirstWindow()
        // The updater isn't needed to draw anything: start it after launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UpdateController.shared.start()
            LowDiskWatcher.shared.start()
        }
    }

    /// Welcome on first run; otherwise the dashboard, when Leftovers is a Dock
    /// app and wasn't started as a login item (those stay quietly in the menu bar).
    private func showFirstWindow() {
        if !UserDefaults.standard.bool(forKey: SettingsKey.hasCompletedOnboarding) {
            WindowCoordinator.shared.showWelcome()
        } else if AppSettings.showInDock, !launchedAsLoginItem {
            WindowCoordinator.shared.showDashboard()
        }
    }

    private var launchedAsLoginItem: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// Clicking the Dock icon brings the dashboard back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowCoordinator.shared.showDashboard() }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(ActionMenuItem(title: "Open Leftovers") { WindowCoordinator.shared.showDashboard() })
        menu.addItem(ActionMenuItem(title: "Settings…") { WindowCoordinator.shared.showSettings() })
        return menu
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
