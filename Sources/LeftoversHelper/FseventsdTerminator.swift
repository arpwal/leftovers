import Darwin
import Foundation
import LeftoversHelperKit

/// Restarts fseventsd the way `killall fseventsd` does, but safely: SIGTERM
/// first, SIGKILL only if it is still the same process after the grace
/// period. Identity (path + start time) is re-checked right before every
/// signal, so a recycled pid is never hit. launchd respawns fseventsd.
enum FseventsdTerminator {
    private static let pollInterval: useconds_t = 250_000
    private static let killConfirmation: TimeInterval = 5

    static func restart() -> RestartOutcome {
        guard let target = FseventsdProcess.locate() else {
            return RestartOutcome(result: .notRunning, detail: "fseventsd isn't running")
        }
        if let failure = signal(target, SIGTERM) { return failure }
        if waitForExit(target, within: HelperConstants.terminateGracePeriod) {
            return RestartOutcome(result: .terminated, detail: "fseventsd (pid \(target.pid)) quit and launchd restarted it")
        }
        if let failure = signal(target, SIGKILL) { return failure }
        return waitForExit(target, within: killConfirmation)
            // SIGKILL skips the journal flush; the outcome and the app's log say so.
            ? RestartOutcome(result: .forceKilled, detail: "fseventsd (pid \(target.pid)) didn't quit within \(Int(HelperConstants.terminateGracePeriod)) s and was force-quit (SIGKILL); events it hadn't saved to its journal were lost")
            : RestartOutcome(result: .failed, detail: "fseventsd (pid \(target.pid)) survived SIGKILL")
    }

    /// Sends `signal` only if `target` is still the same fseventsd. Returns
    /// nil on success; a vanished target counts as success (it already exited).
    private static func signal(_ target: FseventsdIdentity, _ signal: Int32) -> RestartOutcome? {
        guard FseventsdProcess.isAlive(target) else { return nil }
        guard kill(target.pid, signal) == 0 else {
            if errno == ESRCH { return nil }
            return RestartOutcome(result: .failed, detail: "kill: \(String(cString: strerror(errno)))")
        }
        return nil
    }

    /// Polls until `target` is gone; true if it exited in time.
    private static func waitForExit(_ target: FseventsdIdentity, within seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if !FseventsdProcess.isAlive(target) { return true }
            usleep(pollInterval)
        }
        return !FseventsdProcess.isAlive(target)
    }
}
