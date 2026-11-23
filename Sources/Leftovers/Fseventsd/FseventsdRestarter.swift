import Foundation
import LeftoversHelperKit

/// Restarts fseventsd by the best available route and logs the attempt.
/// - The approved helper: no prompt; the only route automatic restarts use.
/// - Otherwise, for restarts the user asked for: the administrator prompt,
///   also used if the helper fails to answer.
enum FseventsdRestarter {
    /// nil when nothing was attempted (an automatic restart without the helper).
    static func restart(trigger: FseventsdRestartEntry.Trigger, before: FseventsdReading?) async -> FseventsdRestartEntry? {
        let helperReady = PrivilegedHelper.status.isReady
        guard helperReady || trigger != .automatic else { return nil }
        var method = FseventsdRestartEntry.Method.administratorPrompt
        var outcome: RestartOutcome?
        if helperReady {
            method = .helper
            outcome = await HelperClient.restartFseventsd()
        }
        let helperSettled = outcome.map { $0.succeeded || $0.result == .notRunning } ?? false
        if trigger != .automatic, !helperSettled {
            method = .administratorPrompt
            outcome = await Task.detached { AdminPromptRestarter.restart() }.value
        }
        let entry = makeEntry(trigger: trigger, method: method, before: before,
                              outcome: outcome ?? RestartOutcome(result: .failed, detail: "Nothing ran"))
        FseventsdRestartLog().append(entry)
        return entry
    }

    private static func makeEntry(trigger: FseventsdRestartEntry.Trigger, method: FseventsdRestartEntry.Method,
                                  before: FseventsdReading?, outcome: RestartOutcome) -> FseventsdRestartEntry {
        FseventsdRestartEntry(date: Date(), trigger: trigger, method: method, cpuPercentBefore: before?.cpuPercent,
                              memoryBytesBefore: before?.memoryBytes, result: outcome.result, detail: outcome.detail)
    }
}
