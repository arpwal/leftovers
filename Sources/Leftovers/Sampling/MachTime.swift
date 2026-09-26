import Darwin

/// `rusage_info` CPU times are mach absolute-time ticks, not nanoseconds.
/// On Apple Silicon one tick is 125/3 ns, so skipping this conversion
/// understates CPU usage ~41×.
enum MachTime {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func nanoseconds(fromTicks ticks: UInt64) -> UInt64 {
        guard timebase.denom != 0 else { return ticks }
        return ticks.multipliedReportingOverflow(by: UInt64(timebase.numer)).overflow
            ? ticks / UInt64(timebase.denom) * UInt64(timebase.numer)
            : ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
    }
}
