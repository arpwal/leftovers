import AppKit
import Sparkle

/// `Leftovers --check-updates [--install]`: prints the updater's state, runs
/// one check against the live feed, and reports the outcome. With `--install`
/// it downloads a found update and installs it immediately (Sparkle replaces
/// this app bundle). Diagnoses update problems without any UI.
@MainActor
enum UpdateCheckCommand {
    static let flag = "--check-updates"
    private static let timeout: TimeInterval = 90
    private static let reporter = Reporter()

    static func runIfRequested() {
        guard CommandLine.arguments.contains(flag) else { return }
        NSApplication.shared.setActivationPolicy(.prohibited)
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                 userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil),
                                 delegate: reporter)
        do { try updater.start() } catch { print("updater failed to start: \(error)"); exit(1) }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "?"
        print("""
        this build: \(version)
        feed: \(updater.feedURL?.absoluteString ?? "none")
        automatic checks: \(updater.automaticallyChecksForUpdates), automatic downloads: \(updater.automaticallyDownloadsUpdates)
        interval: \(Int(updater.updateCheckInterval))s, last check: \(updater.lastUpdateCheckDate.map { "\($0)" } ?? "never")
        can check now: \(updater.canCheckForUpdates)
        """)
        if CommandLine.arguments.contains("--install") {
            updater.automaticallyDownloadsUpdates = true
            updater.checkForUpdatesInBackground()
        } else {
            updater.checkForUpdateInformation()
        }
        let deadline = Date().addingTimeInterval(timeout)
        while !reporter.finished, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.5)) }
        print(reporter.finished ? reporter.outcome : "no answer within \(Int(timeout))s")
        exit(reporter.failed ? 1 : 0)
    }
}

/// Collects Sparkle's delegate callbacks for the command above.
private final class Reporter: NSObject, SPUUpdaterDelegate {
    var finished = false
    var failed = false
    var outcome = ""

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        outcome = "update available: \(item.displayVersionString) (build \(item.versionString)), signed and valid"
    }

    /// Only reached with `--install`: the update is downloaded and verified.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock: @escaping () -> Void) -> Bool {
        outcome = "downloaded and verified \(item.displayVersionString); installing now"
        print(outcome)
        finished = true   // the installer takes over from here
        immediateInstallationBlock()
        return true
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        outcome = "up to date"
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if let error, outcome.isEmpty { outcome = "check failed: \(error.localizedDescription)"; failed = true }
        finished = true
    }
}
