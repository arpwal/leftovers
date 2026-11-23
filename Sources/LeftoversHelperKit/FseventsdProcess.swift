import Darwin
import Foundation

/// A running fseventsd, pinned by pid AND start time: a pid alone can be
/// reused by an unrelated process, the pair can't.
public struct FseventsdIdentity: Hashable, Sendable {
    public let pid: pid_t
    public let startSeconds: UInt64
    public let startMicroseconds: UInt64

    public var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startSeconds) + TimeInterval(startMicroseconds) / 1_000_000)
    }
}

/// Finds fseventsd and re-checks it. Works unprivileged: pid, path and start
/// time of root processes are readable by everyone (memory and CPU are not).
public enum FseventsdProcess {
    /// The live fseventsd: root-owned, running the system binary at the expected path.
    public static func locate() -> FseventsdIdentity? {
        allPids().lazy.compactMap(identity(ifFseventsd:)).first
    }

    /// True while `identity` still names the same live (non-zombie) fseventsd.
    public static func isAlive(_ identity: FseventsdIdentity) -> Bool {
        self.identity(ifFseventsd: identity.pid) == identity
    }

    /// Reads the kernel's process record with sysctl: unlike PROC_PIDTBSDINFO
    /// it works unprivileged for root processes, and it carries the start time.
    private static func identity(ifFseventsd pid: pid_t) -> FseventsdIdentity? {
        guard let record = kinfo(pid), record.kp_eproc.e_ucred.cr_uid == 0, record.kp_proc.p_stat != zombieStatus,
              executablePath(pid) == HelperConstants.fseventsdPath else { return nil }
        let start = record.kp_proc.p_starttime
        return FseventsdIdentity(pid: pid, startSeconds: UInt64(start.tv_sec), startMicroseconds: UInt64(start.tv_usec))
    }

    /// SZOMB in <sys/proc.h>: already exited, only awaiting its parent.
    private static let zombieStatus: CChar = 5

    private static func kinfo(_ pid: pid_t) -> kinfo_proc? {
        var record = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, u_int(mib.count), &record, &size, nil, 0) == 0, size > 0 else { return nil }
        return record.kp_proc.p_pid == pid ? record : nil
    }

    private static func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func allPids() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 128)
        let count = pids.withUnsafeMutableBufferPointer {
            proc_listallpids($0.baseAddress, Int32($0.count * MemoryLayout<pid_t>.stride))
        }
        return count > 0 ? pids.prefix(Int(count)).filter { $0 > 0 } : []
    }
}
