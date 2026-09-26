import AppKit

/// Makes ⌘Q close the window instead of the app (by default), so the menu-bar
/// item keeps running. Logout, restart, and "Quit Memory Janitor" from the
/// menu still quit for real.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by `QuitController` right before an intentional, full quit.
    static var fullQuitRequested = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !Self.fullQuitRequested, AppSettings.closeBehavior == .keepInMenuBar,
              isCommandQKeystroke(NSApp.currentEvent) else { return .terminateNow }
        NSApp.windows.filter { $0.isVisible && $0.canBecomeKey }.forEach { $0.close() }
        return .terminateCancel
    }

    /// With "Quit Memory Janitor" selected, closing the last window quits.
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
enum QuitController {
    static func quitCompletely() {
        AppDelegate.fullQuitRequested = true
        NSApp.terminate(nil)
    }
}
