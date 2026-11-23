import Foundation

/// Why the watchdog is notifying instead of (or after) restarting.
/// Each kind is rate-limited on its own, once per cooldown window.
enum WatchdogAlert: String, Codable, CaseIterable, Sendable {
    /// Over the limits; automatic restarts are off in Settings.
    case autoRestartOff
    /// Over the limits; automatic restarts are on but the helper isn't allowed.
    case helperNotReady
    /// Crossed the limits again within the cooldown after an automatic restart.
    case withinCooldown
    /// Kept relapsing soon after restarts: its normal size here is above the limit.
    case paused
    /// Restarted, but no new fseventsd appeared within a minute.
    case noRespawn
}

/// When each alert kind was last posted (monotonic).
struct AlertStamps: Codable, Equatable, Sendable {
    var autoRestartOff: MonotonicStamp?
    var helperNotReady: MonotonicStamp?
    var withinCooldown: MonotonicStamp?
    var paused: MonotonicStamp?
    var noRespawn: MonotonicStamp?

    subscript(alert: WatchdogAlert) -> MonotonicStamp? {
        get {
            switch alert {
            case .autoRestartOff: return autoRestartOff
            case .helperNotReady: return helperNotReady
            case .withinCooldown: return withinCooldown
            case .paused: return paused
            case .noRespawn: return noRespawn
            }
        }
        set {
            switch alert {
            case .autoRestartOff: autoRestartOff = newValue
            case .helperNotReady: helperNotReady = newValue
            case .withinCooldown: withinCooldown = newValue
            case .paused: paused = newValue
            case .noRespawn: noRespawn = newValue
            }
        }
    }
}
