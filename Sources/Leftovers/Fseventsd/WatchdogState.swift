import Foundation

/// Limits to suggest when automatic restarts pause: what fseventsd keeps
/// returning to on this Mac, with headroom.
struct LimitSuggestion: Codable, Equatable, Sendable {
    let memoryMB: Int?
    let cpuPercent: Double?
}

/// The watchdog's memory between refreshes and across launches (the app and
/// the CLI share it), so relaunching can't bypass the cooldown or backoff.
struct WatchdogState: Codable, Equatable, Sendable {
    /// Any restart (app, notification or CLI): starts the settle period.
    var lastRestart: MonotonicStamp?
    var lastAutomaticRestart: MonotonicStamp?
    /// Current time between automatic restarts; doubles on quick relapses.
    var cooldown: TimeInterval
    /// Times it crossed the limits again within 2× the cooldown of an automatic restart.
    var quickRelapses = 0
    /// Automatic restarts stopped after too many quick relapses.
    var paused = false
    var suggestion: LimitSuggestion?
    /// True from crossing the limits until it's healthy again or restarted.
    var episodeOpen = false
    /// Start of the current healthy stretch, for resetting the backoff.
    var healthySince: MonotonicStamp?
    var alerts = AlertStamps()

    static func initial(cooldown: TimeInterval) -> WatchdogState { WatchdogState(cooldown: cooldown) }

    mutating func recordRestart(automatic: Bool, at now: MonotonicStamp) {
        lastRestart = now
        if automatic { lastAutomaticRestart = now }
        episodeOpen = false
        healthySince = nil
    }

    /// Back to the base cooldown with automatic restarts resumed.
    mutating func resetBackoff(baseCooldown: TimeInterval) {
        cooldown = baseCooldown
        quickRelapses = 0
        paused = false
        suggestion = nil
    }
}

/// `~/Library/Application Support/Leftovers/fseventsd-watchdog.json`.
struct WatchdogStateStore {
    var url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Leftovers/fseventsd-watchdog.json")

    func load(baseCooldown: TimeInterval) -> WatchdogState {
        guard let data = try? Data(contentsOf: url),
              var state = try? JSONDecoder().decode(WatchdogState.self, from: data) else {
            return .initial(cooldown: baseCooldown)
        }
        state.cooldown = max(state.cooldown, baseCooldown) // never below the (clamped) base
        return state
    }

    func save(_ state: WatchdogState) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(state).write(to: url, options: .atomic)
    }

    /// Read, change and write back in one step.
    func update(baseCooldown: TimeInterval, _ change: (inout WatchdogState) -> Void) {
        var state = load(baseCooldown: baseCooldown)
        change(&state)
        save(state)
    }
}
