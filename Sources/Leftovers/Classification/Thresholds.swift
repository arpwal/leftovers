import Foundation

/// Every tunable number behind the leak heuristics, in one place.
enum Thresholds {
    static let gibibyte: UInt64 = 1 << 30

    /// Hoarding: footprint at least this big…
    static let hoardingMinFootprint: UInt64 = 2 * gibibyte
    /// …and at least this many times larger than what is in RAM (i.e. mostly swapped).
    static let hoardingSwappedRatio: Double = 4
    /// …and alive this long, so a busy build that just paged out is not flagged.
    static let hoardingMinAge: TimeInterval = 3_600

    /// A detached dev process must be at least this old before it is flagged.
    static let detachedMinAge: TimeInterval = 12 * 3_600

    /// Large-while-idle: footprint at least this big, idle, and at least this old.
    static let largeIdleFootprint: UInt64 = 8 * gibibyte
    static let largeIdleMinAge: TimeInterval = 3_600

    /// Below this CPU% a process counts as idle.
    static let idleCpuPercent: Double = 1

    /// Rows under this footprint are hidden from the lists as noise.
    static let listMinFootprint: UInt64 = 50 << 20

    // MARK: fseventsd watchdog (defaults; CPU and memory are adjustable in Settings)

    /// fseventsd counts as runaway above this CPU%…
    static let fseventsdCpuPercent: Double = 10
    /// …only when every sample over this long stays above it: builds spike it briefly.
    static let fseventsdSustainedCpu: TimeInterval = 120
    /// A fresh fseventsd uses ~5 MB; one that has leaked for weeks reaches many GB.
    static let fseventsdMemory: UInt64 = 50 << 20
    /// At most one automatic restart per this long: each restart makes Time
    /// Machine and Spotlight rescan, so a re-cross within it only alerts.
    /// Quick relapses double it (up to 24 h); see `WatchdogPolicy`. Each alert
    /// kind also repeats at most once per (current) cooldown.
    static let fseventsdRestartCooldown: TimeInterval = 30 * 60
    /// The footprint read (`top`, ~0.5 s of CPU) runs at most this often;
    /// the cheap resident-size and CPU read runs every refresh.
    static let fseventsdFootprintInterval: TimeInterval = 2 * 60
}
