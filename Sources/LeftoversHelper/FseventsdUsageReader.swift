import Darwin
import Foundation
import LeftoversHelperKit

/// Reads fseventsd's footprint, resident size and CPU time. Needs root:
/// proc_pid_rusage on a root process fails with EPERM for anyone else.
enum FseventsdUsageReader {
    static func read() -> HelperReading? {
        guard let identity = FseventsdProcess.locate(), let usage = rusage(identity.pid),
              FseventsdProcess.isAlive(identity) else { return nil }
        return HelperReading(identity: identity, footprintBytes: usage.ri_phys_footprint, residentBytes: usage.ri_resident_size,
                             cpuTimeNanos: MachTicks.nanoseconds(usage.ri_user_time + usage.ri_system_time))
    }

    private static func rusage(_ pid: pid_t) -> rusage_info_v4? {
        var usage = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        return status == 0 ? usage : nil
    }
}
