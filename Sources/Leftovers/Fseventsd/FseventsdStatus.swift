import Foundation

/// What the watchdog knows about fseventsd right now. A reading that can't
/// be taken is `.unavailable`, never shown as 0.
enum FseventsdStatus: Equatable, Sendable {
    /// Watching is off in Settings.
    case off
    case notRunning
    /// Neither the helper nor `ps` could read it.
    case unavailable(String)
    /// Just restarted: readings are ignored until the new one settles.
    case settling(until: Date)
    case measured(FseventsdHealth)

    var health: FseventsdHealth? {
        if case let .measured(health) = self { return health }
        return nil
    }

    var label: String {
        switch self {
        case .off: return "Not watched"
        case .notRunning: return "Not running"
        case let .unavailable(reason): return "Reading unavailable (\(reason))"
        case .settling: return "Just restarted; settling"
        case let .measured(health): return health.needsRestart ? "Running away: \(health.reason)" : "Healthy: \(health.usage)"
        }
    }
}
