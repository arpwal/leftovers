import Foundation

enum WatchdogAction: Equatable, Sendable {
    case none
    case restart
    case alert(WatchdogAlert)
}

/// The watchdog's rules, in one pure place. For each settled reading:
/// - healthy: close the episode; after 24 h healthy, reset the backoff;
/// - newly over the limits within 2× the cooldown of an automatic restart is
///   a quick relapse: double the cooldown (≤ 24 h); after 3, pause automatic
///   restarts and suggest higher limits (its normal size here is above them);
/// - restart automatically when allowed and outside the cooldown, otherwise
///   alert, each kind at most once per cooldown window.
struct WatchdogPolicy {
    let autoRestart: Bool
    let helperReady: Bool
    let limits: FseventsdLimits

    static let maximumCooldown: TimeInterval = 24 * 3_600
    static let relapseLimit = 3
    static let healthyReset: TimeInterval = 24 * 3_600

    func evaluate(_ health: FseventsdHealth, state: inout WatchdogState, now: MonotonicStamp) -> WatchdogAction {
        guard health.needsRestart else { recordHealthy(&state, now: now); return .none }
        state.healthySince = nil
        if !state.episodeOpen { openEpisode(&state, health: health, now: now) }
        guard let blocker = blocker(state, now: now) else { return .restart }
        return alertIfDue(blocker, state: &state, now: now)
    }

    /// Posts `alert` unless the same kind went out within the cooldown window.
    func alertIfDue(_ alert: WatchdogAlert, state: inout WatchdogState, now: MonotonicStamp) -> WatchdogAction {
        if let last = state.alerts[alert], last.elapsed(until: now) < state.cooldown { return .none }
        state.alerts[alert] = now
        return .alert(alert)
    }

    private func recordHealthy(_ state: inout WatchdogState, now: MonotonicStamp) {
        state.episodeOpen = false
        let since = state.healthySince ?? now
        state.healthySince = since
        if since.elapsed(until: now) >= Self.healthyReset { state.resetBackoff(baseCooldown: limits.cooldown) }
    }

    private func openEpisode(_ state: inout WatchdogState, health: FseventsdHealth, now: MonotonicStamp) {
        state.episodeOpen = true
        guard let last = state.lastAutomaticRestart, last.elapsed(until: now) < 2 * state.cooldown else { return }
        state.quickRelapses += 1
        state.cooldown = min(state.cooldown * 2, Self.maximumCooldown)
        if state.quickRelapses >= Self.relapseLimit {
            state.paused = true
            state.suggestion = Self.suggestion(for: health)
        }
    }

    /// What stops an automatic restart right now, if anything.
    private func blocker(_ state: WatchdogState, now: MonotonicStamp) -> WatchdogAlert? {
        if state.paused { return .paused }
        if !autoRestart { return .autoRestartOff }
        if !helperReady { return .helperNotReady }
        if let last = state.lastAutomaticRestart, last.elapsed(until: now) < state.cooldown { return .withinCooldown }
        return nil
    }

    /// 1.5× what it's using now, rounded up (memory to 50 MB, CPU to 5%).
    static func suggestion(for health: FseventsdHealth) -> LimitSuggestion {
        let memoryMB = Double(health.reading.memoryBytes >> 20) * 1.5
        let cpu = (health.reading.cpuPercent ?? 0) * 1.5
        return LimitSuggestion(
            memoryMB: health.overMemory ? Int((memoryMB / 50).rounded(.up) * 50) : nil,
            cpuPercent: health.sustainedCpu ? min((cpu / 5).rounded(.up) * 5, FseventsdLimits.cpuRange.upperBound) : nil)
    }
}
