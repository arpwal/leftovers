import Darwin
import Foundation

/// fseventsd's usage as root reads it (proc_pid_rusage), carried as JSON.
public struct HelperReading: Codable, Sendable, Equatable {
    public let identity: FseventsdIdentity
    public let footprintBytes: UInt64
    public let residentBytes: UInt64
    /// Cumulative user + system CPU time.
    public let cpuTimeNanos: UInt64

    public init(identity: FseventsdIdentity, footprintBytes: UInt64, residentBytes: UInt64, cpuTimeNanos: UInt64) {
        self.identity = identity
        self.footprintBytes = footprintBytes
        self.residentBytes = residentBytes
        self.cpuTimeNanos = cpuTimeNanos
    }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

    public static func decode(_ data: Data) -> HelperReading? {
        try? JSONDecoder().decode(HelperReading.self, from: data)
    }
}

/// rusage CPU times are mach ticks, not nanoseconds (125/3 ns on Apple silicon).
public enum MachTicks {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    public static func nanoseconds(_ ticks: UInt64) -> UInt64 {
        guard timebase.denom != 0 else { return ticks }
        return UInt64(Double(ticks) * Double(timebase.numer) / Double(timebase.denom))
    }
}
