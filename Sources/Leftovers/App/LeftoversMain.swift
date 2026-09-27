import AppKit

/// Entry point. Command-line modes run and exit; otherwise this starts the
/// menu-bar app. The AppKit lifecycle (rather than SwiftUI's `App`) gives
/// full control over the status item, the menu and window lifetimes.
@main
enum LeftoversMain {
    @MainActor
    static func main() {
        StartupTrace.mark("main")
        Usage.handleHelpAndUnknownFlags()
        CommandLineInterface.runIfRequested()
        SnapshotCommand.runIfRequested()
        UpdateCheckCommand.runIfRequested()
        JobsCommand.runIfRequested()
        WorktreesCommand.runIfRequested()
        StartupTrace.mark("command-line checks done")
        // Every command-line mode has exited by now; only the app gets here.
        SingleInstance.handOffIfAlreadyRunning()
        // Start reading memory before AppKit sets up (~125 ms): the first
        // reading is then usually ready when the first window appears.
        let store = MonitorStore()
        let app = NSApplication.shared
        StartupTrace.mark("NSApplication created")
        let delegate = AppDelegate(store: store)
        app.delegate = delegate
        app.setActivationPolicy(AppSettings.activationPolicy) // Dock icon unless hidden in Settings
        StartupTrace.mark("entering run loop")
        withExtendedLifetime(delegate) { app.run() }
    }
}
