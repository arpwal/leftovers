import AppKit

/// Owns the app's long-lived pieces and decides what ⌘Q means.
///
/// ⌘Q closes the window and keeps the menu-bar item running (default).
/// "Quit Leftovers" in the menu, logout and restart always quit for real.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by `QuitController` right before an intentional, full quit.
    static var fullQuitRequested = false

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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !Self.fullQuitRequested, AppSettings.closeBehavior == .keepInMenuBar,
              isCommandQKeystroke(NSApp.currentEvent) else { return .terminateNow }
        WindowCoordinator.shared.closeAll()
        return .terminateCancel
    }

    /// With "Quit Leftovers" selected in Settings, closing the last window quits.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppSettings.closeBehavior == .quitCompletely
    }

    /// Only a ⌘Q keystroke is intercepted; everything else (logout, `kill`) quits.
    private func isCommandQKeystroke(_ event: NSEvent?) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        return event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "q"
    }
}

/// The one place that quits the app entirely.
@MainActor
enum QuitController {
    static func quitCompletely() {
        AppDelegate.fullQuitRequested = true
        NSApp.terminate(nil)
    }
}
