import Foundation

/// Watches fseventsd on the app's refresh cycle and restarts it when it runs
/// away (macOS's file-event daemon can leak to many GB and pin a core after
/// weeks of heavy file churn; a restart fixes it, launchd respawns it).
/// fseventsd never joins Likely Leaks: Clean Up and `--clean` send user-level
/// signals, so it has its own state, actions and helper route here.
@MainActor
final class FseventsdWatchdog: ObservableObject {
    static let shared = FseventsdWatchdog()
    private static let helperOfferedKey = "fseventsdHelperOffered"
    /// Readings right after a restart describe a process still starting up.
    static let settlePeriod: TimeInterval = 2 * 60

    @Published private(set) var status: FseventsdStatus = .off
    @Published private(set) var lastRestart: FseventsdRestartEntry?
    @Published private(set) var isRestarting = false
    @Published private(set) var helperStatus: HelperStatus = .notRegistered
    @Published private(set) var state: WatchdogState
    @Published private(set) var message: String?

    private let sampler = FseventsdSampler()
    private let log = FseventsdRestartLog()
    private let store = WatchdogStateStore()
    private var cpu = CpuOverTracker()
    private var loop: Task<Void, Never>?
    private var checkedHelperVersion = false

    init() { state = WatchdogStateStore().load(baseCooldown: AppSettings.fseventsdLimits.cooldown) }

    var health: FseventsdHealth? { status.health }
    var needsRestart: Bool { health?.needsRestart ?? false }
    var limits: FseventsdLimits { AppSettings.fseventsdLimits }

    func start() {
        lastRestart = log.last
        offerHelperOnce()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: AppSettings.refreshInterval.duration)
            }
        }
    }

    /// One reading, then the policy's decision. State is re-read from disk
    /// each time, so a restart made from the CLI is respected here.
    func tick() async {
        await refreshHelper()
        let limits = AppSettings.fseventsdLimits
        state = store.load(baseCooldown: limits.cooldown)
        lastRestart = log.last
        guard AppSettings.watchFseventsd else { status = .off; cpu.reset(); return }
        guard !isRestarting else { return }
        if let settled = settleEnd() { status = .settling(until: settled); cpu.reset(); return }
        switch await sampler.sample(useHelper: helperStatus.isReady) {
        case .notRunning: status = .notRunning; cpu.reset()
        case let .unavailable(reason): status = .unavailable(reason)
        case let .reading(reading): judge(reading, limits: limits)
        }
    }

    /// Restarts now (menu, dashboard, notification button or the policy).
    func restart(trigger: FseventsdRestartEntry.Trigger) async {
        guard !isRestarting else { return }
        isRestarting = true
        message = "Restarting fseventsd… it can take up to a minute to save its state."
        let result = await FseventsdRestarter.restart(trigger: trigger, before: health?.reading)
        isRestarting = false
        switch result {
        case let .failure(refusal): message = refusal.message
        case let .success(entry): finish(entry, trigger: trigger)
        }
        await sampler.forget()
        cpu.reset()
        await tick()
    }

    /// Automatic restarts on: register the helper (macOS asks once in Login
    /// Items). Off: unregister it, so no root daemon stays installed unused.
    func setAutoRestart(_ enabled: Bool) {
        if enabled { enableHelper() } else { PrivilegedHelper.unregister() }
        helperStatus = PrivilegedHelper.status
    }

    /// Registers the helper and opens Login Items for the one-time approval.
    func enableHelper() {
        message = PrivilegedHelper.register()
        helperStatus = PrivilegedHelper.status
        if helperStatus == .requiresApproval { PrivilegedHelper.openLoginItems() }
    }

    /// Applies the suggested limits and resumes automatic restarts.
    func raiseLimits() {
        if let memory = state.suggestion?.memoryMB { UserDefaults.standard.set(memory, forKey: SettingsKey.fseventsdMemoryMB) }
        if let cpu = state.suggestion?.cpuPercent { UserDefaults.standard.set(cpu, forKey: SettingsKey.fseventsdCpuPercent) }
        resumeAutomaticRestarts()
    }

    func resumeAutomaticRestarts() {
        let base = AppSettings.fseventsdLimits.cooldown
        store.update(baseCooldown: base) { $0.resetBackoff(baseCooldown: base) }
        state = store.load(baseCooldown: base)
        message = "Automatic restarts resumed."
    }

    private func judge(_ reading: FseventsdReading, limits: FseventsdLimits) {
        cpu.update(with: reading, limit: limits.cpuPercent)
        let health = FseventsdHealth(reading: reading, limits: limits, cpuOverFor: cpu.overFor(at: reading.takenAt))
        status = .measured(health)
        let policy = WatchdogPolicy(autoRestart: AppSettings.autoRestartFseventsd, helperReady: helperStatus.isReady, limits: limits)
        var next = state
        let action = policy.evaluate(health, state: &next, now: reading.takenAt)
        store.save(next)
        state = next
        switch action {
        case .none: break
        case .restart: Task { await restart(trigger: .automatic) }
        case let .alert(alert): FseventsdNotifier.post(alert, health: health, state: next)
        }
    }

    private func finish(_ entry: FseventsdRestartEntry, trigger: FseventsdRestartEntry.Trigger) {
        lastRestart = entry
        message = entry.succeeded ? "Restarted fseventsd." : "Couldn't restart fseventsd: \(entry.detail)"
        if trigger == .automatic || entry.succeeded { FseventsdNotifier.postRestarted(entry) }
        guard entry.succeeded, entry.newPid == nil else { return }
        // No new fseventsd within a minute: tell the user (rate-limited like other alerts).
        var next = state
        let policy = WatchdogPolicy(autoRestart: false, helperReady: false, limits: AppSettings.fseventsdLimits)
        if case .alert = policy.alertIfDue(.noRespawn, state: &next, now: .now()) {
            store.save(next)
            FseventsdNotifier.post(.noRespawn, health: nil, state: next)
        }
    }

    /// When the settle period after the last restart ends, if it hasn't yet.
    private func settleEnd() -> Date? {
        guard let last = state.lastRestart else { return nil }
        let remaining = Self.settlePeriod - last.elapsed()
        return remaining > 0 ? Date().addingTimeInterval(remaining) : nil
    }

    /// Updates the helper's status, and once per launch checks the running
    /// helper is from this build (after a Sparkle update it may not be).
    private func refreshHelper() async {
        helperStatus = PrivilegedHelper.status
        guard helperStatus.isReady, !checkedHelperVersion else { return }
        guard let version = await HelperClient.version() else { return }
        checkedHelperVersion = true
        if version != PrivilegedHelper.appBuild {
            message = PrivilegedHelper.reregister() ?? "Updated the helper to this version."
            helperStatus = PrivilegedHelper.status
        }
    }

    /// Automatic restarts are on by default, so register the helper once at
    /// launch: macOS then lists it in Login Items for the user to allow.
    private func offerHelperOnce() {
        let defaults = UserDefaults.standard
        guard AppSettings.watchFseventsd, AppSettings.autoRestartFseventsd,
              !defaults.bool(forKey: Self.helperOfferedKey), PrivilegedHelper.status == .notRegistered else { return }
        defaults.set(true, forKey: Self.helperOfferedKey)
        PrivilegedHelper.register()
    }
}
