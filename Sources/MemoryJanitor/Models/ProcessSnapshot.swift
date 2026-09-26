import Foundation

/// One process as observed at a single sampling instant.
///
/// `footprintBytes` is the number that matters: it is what the process costs the
/// system (RAM + compressed + swapped). `residentBytes` is only the part in RAM —
/// a leaked helper can show 7 MB resident while holding a 59 GB footprint.
struct ProcessSnapshot: Hashable {
    let pid: pid_t
    let ppid: pid_t
    let uid: uid_t
    let name: String
    let executablePath: String
    let workingDirectory: String?
    let startDate: Date
    let footprintBytes: UInt64
    let residentBytes: UInt64
    /// Cumulative user+system CPU time, used to derive CPU% between samples.
    let cpuTimeNanos: UInt64
    let kind: ProcessKind

    var age: TimeInterval { Date().timeIntervalSince(startDate) }

    /// Stable identity across samples: a pid can be reused by a new process.
    var identity: ProcessIdentity { ProcessIdentity(pid: pid, startDate: startDate) }
}

/// A pid plus its start time — the only safe way to know a pid still means
/// the same process before sending it a signal.
struct ProcessIdentity: Hashable {
    let pid: pid_t
    let startDate: Date
}
