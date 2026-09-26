import AppKit

/// Entry point. Command-line modes run and exit; otherwise this starts the
/// menu-bar app. The AppKit lifecycle (rather than SwiftUI's `App`) gives
/// full control over the status item, the menu and window lifetimes.
@main
enum LeftoversMain {
    @MainActor
    static func main() {
        CommandLineInterface.runIfRequested()
        SnapshotCommand.runIfRequested()
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        withExtendedLifetime(delegate) { app.run() }
    }
}
