import Foundation

/// Why the watchdog is alerting instead of restarting.
enum WatchdogAlertReason: Equatable, Sendable {
    /// Automatic restarts are off in Settings.
    case autoRestartOff
    /// Automatic restarts are on but the helper isn't approved yet.
    case helperNotReady
    /// It crossed the limit again within the cooldown after an automatic restart.
    case withinCooldown
}

enum WatchdogAction: Equatable, Sendable {
    case none
    case restart
    case alert(WatchdogAlertReason)
}

/// The watchdog's decision for one over-limit reading. Pure, so the rules
/// are easy to read in one place:
/// - restart automatically when allowed, at most once per cooldown;
/// - otherwise notify, at most once per quiet period.
struct WatchdogPolicy {
    let autoRestart: Bool
    let helperReady: Bool
    let lastAutomaticRestart: Date?
    let lastAlert: Date?
    var cooldown: TimeInterval = Thresholds.fseventsdRestartCooldown
    var alertQuietPeriod: TimeInterval = Thresholds.fseventsdAlertQuietPeriod

    func action(for health: FseventsdHealth, now: Date = Date()) -> WatchdogAction {
        guard health.needsRestart else { return .none }
        if let reason = blocker(now: now) { return canAlert(now: now) ? .alert(reason) : .none }
        return .restart
    }

    /// What stops an automatic restart right now, if anything.
    private func blocker(now: Date) -> WatchdogAlertReason? {
        if !autoRestart { return .autoRestartOff }
        if !helperReady { return .helperNotReady }
        if let last = lastAutomaticRestart, now.timeIntervalSince(last) < cooldown { return .withinCooldown }
        return nil
    }

    private func canAlert(now: Date) -> Bool {
        guard let lastAlert else { return true }
        return now.timeIntervalSince(lastAlert) >= alertQuietPeriod
    }
}
