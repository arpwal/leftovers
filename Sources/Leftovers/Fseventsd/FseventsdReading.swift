import Foundation
import LeftoversHelperKit

/// One reading of fseventsd. It runs as root, so libproc won't give its
/// memory or CPU time to a normal user: those come from the setuid `ps`
/// (resident size, CPU time; every refresh) and `top` (footprint, which
/// includes swapped memory; every couple of minutes).
struct FseventsdReading: Sendable, Equatable {
    let identity: FseventsdIdentity
    let residentBytes: UInt64
    /// RAM + compressed + swapped. nil until `top` has been read once.
    let footprintBytes: UInt64?
    /// CPU% since the previous reading; nil on the first one.
    let cpuPercent: Double?
    /// How long the previous reading was before this one (the CPU% window).
    let interval: TimeInterval?
    let takenAt: Date

    /// The memory the thresholds use: the footprint when known (a leaked
    /// fseventsd is mostly swapped out), never less than what's in RAM.
    var memoryBytes: UInt64 { max(residentBytes, footprintBytes ?? 0) }
    var uptime: TimeInterval { takenAt.timeIntervalSince(identity.startDate) }
}

/// The limits fseventsd is held to (Settings, defaults in `Thresholds`).
struct FseventsdLimits: Equatable, Sendable {
    let cpuPercent: Double
    let memoryBytes: UInt64
    let sustainedFor: TimeInterval
}
