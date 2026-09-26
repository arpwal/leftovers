import Darwin
import Foundation

/// Startup timing, printed only when `LEFTOVERS_TRACE=1`. Times are measured
/// from the moment the kernel started the process, so they include dyld and
/// framework loading, not just our own code.
enum StartupTrace {
    static let enabled = ProcessInfo.processInfo.environment["LEFTOVERS_TRACE"] == "1"

    private static let processStart: Date = {
        guard let info = LibProc.bsdInfo(getpid()) else { return Date() }
        return LibProc.startDate(info)
    }()

    static func mark(_ milestone: String) {
        guard enabled else { return }
        let ms = Int(Date().timeIntervalSince(processStart) * 1000)
        print("[startup] \(ms) ms  \(milestone)")
        fflush(stdout)
    }
}
