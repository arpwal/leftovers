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
}
