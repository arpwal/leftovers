import Foundation

/// Watches fseventsd on the app's refresh cycle and restarts it when it runs
/// away (macOS's file-event daemon can leak to many GB and pin a core after
/// weeks of heavy file churn; a restart fixes it, launchd respawns it).
/// Publishes its state for the menu, the dashboard and Settings.
@MainActor
final class FseventsdWatchdog: ObservableObject {
    static let shared = FseventsdWatchdog()
    private static let lastAlertKey = "fseventsdLastAlert"
    private static let helperOfferedKey = "fseventsdHelperOffered"

    /// The latest reading judged against the limits; nil when off or not running.
    @Published private(set) var health: FseventsdHealth?
    @Published private(set) var lastRestart: FseventsdRestartEntry?
    @Published private(set) var isRestarting = false
    @Published private(set) var helperStatus: HelperStatus = .notRegistered
    @Published private(set) var message: String?

    private let sampler = FseventsdSampler()
    private let log = FseventsdRestartLog()
    private var window = CpuWindow()
    private var loop: Task<Void, Never>?

    var needsRestart: Bool { health?.needsRestart ?? false }

    func start() {
        FseventsdNotifier.registerCategory()
        lastRestart = log.last
        offerHelperOnce()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: AppSettings.refreshInterval.duration)
            }
        }
    }

    /// One reading, then the policy's decision.
    func tick() async {
        helperStatus = PrivilegedHelper.status
        lastRestart = log.last // also picks up restarts made from the command line
        guard AppSettings.watchFseventsd else { clearReading(); return }
        guard !isRestarting else { return }
        guard let reading = await sampler.sample() else { clearReading(); return }
        if reading.identity != health?.reading.identity { window.reset() }
        if let cpu = reading.cpuPercent, let interval = reading.interval {
            window.add(.init(percent: cpu, interval: interval, at: reading.takenAt), window: Thresholds.fseventsdSustainedCpu)
        }
        let health = FseventsdHealth(reading: reading, limits: AppSettings.fseventsdLimits, window: window)
        self.health = health
        act(on: health)
    }

    /// Restarts now (menu, dashboard, notification button or the policy).
    func restart(trigger: FseventsdRestartEntry.Trigger) async {
        guard !isRestarting else { return }
        isRestarting = true
        message = "Restarting fseventsd… it can take up to a minute to save its state."
        let entry = await FseventsdRestarter.restart(trigger: trigger, before: health?.reading)
        isRestarting = false
        guard let entry else { message = nil; return }
        lastRestart = entry
        message = entry.succeeded ? "Restarted fseventsd." : "Couldn't restart fseventsd: \(entry.detail)"
        if trigger == .automatic || entry.succeeded { FseventsdNotifier.postRestarted(entry) }
        await sampler.forget()
        clearReading()
        try? await Task.sleep(for: .seconds(2)) // launchd respawns it within a moment
        await tick()
    }

    /// Registers the helper and opens Login Items for the one-time approval.
    func enableHelper() {
        message = PrivilegedHelper.register()
        helperStatus = PrivilegedHelper.status
        if helperStatus == .requiresApproval { PrivilegedHelper.openLoginItems() }
    }

    private func act(on health: FseventsdHealth) {
        let policy = WatchdogPolicy(autoRestart: AppSettings.autoRestartFseventsd, helperReady: helperStatus.isReady,
                                    lastAutomaticRestart: log.lastAutomatic?.date, lastAlert: lastAlert)
        switch policy.action(for: health) {
        case .none: break
        case .restart: Task { await restart(trigger: .automatic) }
        case let .alert(reason):
            lastAlert = Date()
            FseventsdNotifier.postAlert(health, reason: reason)
        }
    }

    /// Automatic restarts are on by default, so register the helper once at
    /// launch: macOS then lists it in Login Items for the user to approve.
    private func offerHelperOnce() {
        let defaults = UserDefaults.standard
        guard AppSettings.watchFseventsd, AppSettings.autoRestartFseventsd,
              !defaults.bool(forKey: Self.helperOfferedKey), PrivilegedHelper.status == .notRegistered else { return }
        defaults.set(true, forKey: Self.helperOfferedKey)
        PrivilegedHelper.register()
    }

    private func clearReading() {
        health = nil
        window.reset()
    }

    private var lastAlert: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastAlertKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastAlertKey) }
    }
}
