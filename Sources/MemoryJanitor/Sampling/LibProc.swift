import Darwin
import Foundation

/// Thin, typed wrappers over libproc. Every call returns nil instead of
/// garbage when the kernel refuses (root-owned process, or it just exited).
enum LibProc {
    static func allPids() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        // Headroom: processes can spawn between the two calls.
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 128)
        let count = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.stride))
        }
        guard count > 0 else { return [] }
        return pids.prefix(Int(count)).filter { $0 > 0 }
    }

    static func bsdInfo(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }

    static func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        return length > 0 ? CString.decode(buffer) : nil
    }

    static func workingDirectory(_ pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = CString.decode(tuple: info.pvi_cdir.vip_path)
        return path.isEmpty ? nil : path
    }

    /// Process start time. Used for both sampling and identity re-checks, so
    /// the two computations are bit-identical and can be compared with `==`.
    static func startDate(_ info: proc_bsdinfo) -> Date {
        let seconds = TimeInterval(info.pbi_start_tvsec)
        let micros = TimeInterval(info.pbi_start_tvusec) / 1_000_000
        return Date(timeIntervalSince1970: seconds + micros)
    }

    /// Footprint, resident size and CPU time. Fails for other users' processes.
    static func resourceUsage(_ pid: pid_t) -> rusage_info_v4? {
        var usage = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return status == 0 ? usage : nil
    }
}

/// Decodes fixed-size C char buffers (arrays or imported tuples).
enum CString {
    static func decode(_ chars: [CChar]) -> String {
        let bytes = chars.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func decode<T>(tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
