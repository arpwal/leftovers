import Foundation
import LeftoversHelperKit

/// One reading of fseventsd. It runs as root, so libproc won't give its
/// memory or CPU time to a normal user. With the helper approved, root reads
/// them (footprint included). Otherwise the setuid `/bin/ps` gives resident
/// size and CPU time every refresh, and `/usr/bin/top` the footprint every
/// couple of minutes.
struct FseventsdReading: Sendable, Equatable {
    enum Source: String, Codable, Sendable {
        case helper, ps
    }

    let identity: FseventsdIdentity
    let residentBytes: UInt64
    /// RAM + compressed + swapped. nil until it has been read once.
    let footprintBytes: UInt64?
    /// CPU% since the previous reading; nil on the first one.
    let cpuPercent: Double?
    /// Seconds since the previous reading (the CPU% interval).
    let interval: TimeInterval?
    let source: Source
    /// When it was taken, on the monotonic clock (windows) and wall clock (display).
    let takenAt: MonotonicStamp

    /// The memory the limit applies to: the footprint when known (a leaked
    /// fseventsd is mostly swapped out), never less than what's in RAM.
    var memoryBytes: UInt64 { max(residentBytes, footprintBytes ?? 0) }
    var uptime: TimeInterval { max(0, takenAt.wall.timeIntervalSince(identity.startDate)) }
}

/// The limits fseventsd is held to: Settings, clamped, defaults in `Thresholds`.
struct FseventsdLimits: Equatable, Sendable {
    let cpuPercent: Double
    let memoryBytes: UInt64
    let sustainedFor: TimeInterval
    /// Base time between automatic restarts (backoff doubles it).
    let cooldown: TimeInterval

    static let cpuRange: ClosedRange<Double> = 1...100
    static let minimumMemoryMB = 20
    static let minimumCooldown: TimeInterval = 10 * 60

    /// Clamps whatever Settings hold, so 0 or nonsense can't cause a restart loop.
    static func clamped(cpuPercent: Double, memoryMB: Int, cooldown: TimeInterval, sustainedFor: TimeInterval) -> FseventsdLimits {
        FseventsdLimits(cpuPercent: min(max(cpuPercent, cpuRange.lowerBound), cpuRange.upperBound),
                        memoryBytes: UInt64(max(memoryMB, minimumMemoryMB)) << 20,
                        sustainedFor: sustainedFor, cooldown: max(cooldown, minimumCooldown))
    }
}
