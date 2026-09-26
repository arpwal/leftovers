import Darwin
import Foundation

enum TerminationResult: Equatable {
    case terminated
    case forceKilled
    case alreadyGone
    case refused(String)
    case failed(errno: Int32)

    var message: String {
        switch self {
        case .terminated: return "Quit cleanly"
        case .forceKilled: return "Force-quit after it ignored the request"
        case .alreadyGone: return "Already exited"
        case let .refused(reason): return "Refused: \(reason)"
        case let .failed(code): return "Failed: \(String(cString: strerror(code)))"
        }
    }
}

/// Stops a process politely (SIGTERM), then forcefully (SIGKILL) if it ignores
/// the request. Re-checks identity first so a recycled pid is never signalled.
struct ProcessTerminator {
    static let gracePeriod: Duration = .seconds(3)
    private static let pollInterval: Duration = .milliseconds(200)

    func terminate(_ process: ClassifiedProcess) async -> TerminationResult {
        guard process.verdict.isKillable else { return .refused(process.verdict.explanation) }
        let identity = process.snapshot.identity
        guard isSameProcess(identity) else { return .alreadyGone }
        guard kill(identity.pid, SIGTERM) == 0 else { return failure() }

        let deadline = ContinuousClock.now + Self.gracePeriod
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: Self.pollInterval)
            if !isSameProcess(identity) { return .terminated }
        }
        guard isSameProcess(identity) else { return .terminated }
        return kill(identity.pid, SIGKILL) == 0 ? .forceKilled : failure()
    }

    /// The pid still exists AND started at the same moment as when we sampled it.
    private func isSameProcess(_ identity: ProcessIdentity) -> Bool {
        guard let info = LibProc.bsdInfo(identity.pid) else { return false }
        // A zombie has already released its memory; it only awaits reaping.
        let zombieStatus: UInt32 = 5 // SZOMB in <sys/proc.h>
        return info.pbi_status != zombieStatus && LibProc.startDate(info) == identity.startDate
    }

    private func failure() -> TerminationResult {
        errno == ESRCH ? .alreadyGone : .failed(errno: errno)
    }
}
