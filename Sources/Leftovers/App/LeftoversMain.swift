import AppKit

/// Entry point. Command-line modes run and exit; otherwise this starts the
/// menu-bar app. The AppKit lifecycle (rather than SwiftUI's `App`) gives
/// full control over the status item, the menu and window lifetimes.
@main
enum LeftoversMain {
    @MainActor
    static func main() {
        StartupTrace.mark("main")
        switch CommandRouter.command(for: CommandLine.arguments) {
        case .app: break
        case .help: print(Usage.text); exit(0)
        case let .unknown(flag): Usage.fail("Unknown option \(flag)")
        case let .missingValue(flag): Usage.fail("\(flag) needs a value")
        case .memoryReport: CommandLineInterface.runAndExit(.report)
        case .memoryJSON: CommandLineInterface.runAndExit(.json)
        case .clean: CommandLineInterface.runAndExit(.clean)
        case let .jobs(json): JobsCommand.runAndExit(json: json)
        case let .worktrees(json): WorktreesCommand.runAndExit(json: json)
        case let .checkUpdates(install): UpdateCheckCommand.runAndExit(install: install)
        case let .snapshot(directory, redact): SnapshotCommand.runAndExit(directory: directory, redact: redact)
        }
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
