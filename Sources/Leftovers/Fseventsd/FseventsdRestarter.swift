import Foundation
import LeftoversHelperKit

/// Why a restart wasn't attempted.
enum RestartRefusal: Error, Equatable {
    /// Another restart (app or CLI) holds the lock.
    case busy
    /// Automatic restarts never show a password prompt; they need the helper.
    case needsHelper
    /// The CLI respects the cooldown unless given `--force`.
    case cooldown(remaining: TimeInterval)

    var message: String {
        switch self {
        case .busy: return "A restart is already in progress"
        case .needsHelper: return "Automatic restarts need the helper; allow it in Login Items"
        case let .cooldown(remaining): return "Restarted recently; try again in \(Format.age(remaining)), or pass --force"
        }
    }
}

/// Restarts fseventsd by the best available route, single-flight across
/// processes, then records it (log + persisted state) and confirms launchd
/// started a new one.
/// - The approved helper: no prompt. The only route for automatic restarts.
/// - Otherwise, only for restarts the user asked for: macOS's administrator
///   prompt, also used if the helper fails to answer.
enum FseventsdRestarter {
    static func restart(trigger: FseventsdRestartEntry.Trigger, before: FseventsdReading?,
                        force: Bool = false) async -> Result<FseventsdRestartEntry, RestartRefusal> {
        let limits = AppSettings.fseventsdLimits
        let store = WatchdogStateStore()
        if trigger == .commandLine, !force, let last = store.load(baseCooldown: limits.cooldown).lastRestart,
           last.elapsed() < limits.cooldown {
            return .failure(.cooldown(remaining: limits.cooldown - last.elapsed()))
        }
        let helperReady = PrivilegedHelper.status.isReady
        guard helperReady || trigger != .automatic else { return .failure(.needsHelper) }
        guard let lock = RestartLock() else { return .failure(.busy) }
        defer { withExtendedLifetime(lock) {} }

        let old = before?.identity ?? FseventsdProcess.locate()
        let (method, outcome) = await run(trigger: trigger, helperReady: helperReady)
        guard outcome.result != .busy else { return .failure(.busy) }
        // A failed automatic attempt still counts, so a broken route isn't retried every refresh.
        if outcome.succeeded || trigger == .automatic {
            store.update(baseCooldown: limits.cooldown) { $0.recordRestart(automatic: trigger == .automatic, at: .now()) }
        }
        let newPid = outcome.succeeded || outcome.result == .notRunning ? await RespawnCheck.waitForNew(replacing: old)?.pid : nil
        let entry = FseventsdRestartEntry(date: Date(), trigger: trigger, method: method, cpuPercentBefore: before?.cpuPercent,
                                          memoryBytesBefore: before?.memoryBytes, result: outcome.result,
                                          detail: outcome.detail, newPid: newPid)
        FseventsdRestartLog().append(entry)
        return .success(entry)
    }

    private static func run(trigger: FseventsdRestartEntry.Trigger,
                            helperReady: Bool) async -> (FseventsdRestartEntry.Method, RestartOutcome) {
        if helperReady {
            let outcome = await HelperClient.restartFseventsd()
            let settled = outcome.succeeded || outcome.result == .notRunning || outcome.result == .busy
            if settled || trigger == .automatic { return (.helper, outcome) }
        }
        return (.administratorPrompt, await Task.detached { AdminPromptRestarter.restart() }.value)
    }
}
