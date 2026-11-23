import Darwin
import Foundation

/// A moment measured on the monotonic clock (counts sleep, ignores wall-clock
/// changes), with the wall time kept for display only. Persisted, so the
/// cooldown and grace windows survive relaunching the app or the CLI.
struct MonotonicStamp: Codable, Equatable, Sendable {
    /// Seconds since boot, including sleep (mach_continuous_time).
    let uptime: TimeInterval
    /// Identifies the boot: uptimes from different boots can't be compared.
    let bootSession: String
    /// For display only; never used for windows.
    let wall: Date

    static func now() -> MonotonicStamp {
        MonotonicStamp(uptime: continuousUptime(), bootSession: bootSessionID, wall: Date())
    }

    /// Seconds from this stamp to `later`. Across a reboot the monotonic clock
    /// restarted, so it falls back to wall time (never negative).
    func elapsed(until later: MonotonicStamp = .now()) -> TimeInterval {
        if bootSession == later.bootSession { return max(0, later.uptime - uptime) }
        return max(0, later.wall.timeIntervalSince(wall))
    }

    /// The same clock, `seconds` earlier (e.g. the start of a CPU interval).
    func shifted(by seconds: TimeInterval) -> MonotonicStamp {
        MonotonicStamp(uptime: uptime + seconds, bootSession: bootSession, wall: wall.addingTimeInterval(seconds))
    }

    private static func continuousUptime() -> TimeInterval {
        TimeInterval(MachTime.nanoseconds(fromTicks: mach_continuous_time())) / 1_000_000_000
    }

    private static let bootSessionID: String = {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buffer, &size, nil, 0) == 0 else { return "unknown" }
        return CString.decode(buffer)
    }()
}
