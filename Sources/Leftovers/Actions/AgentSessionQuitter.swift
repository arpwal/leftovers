import Foundation

/// Quits a coding-agent session and everything it started: the agent first
/// (so it can shut its own tools down), then anything still running.
/// Every process still goes through `ProtectionPolicy` and the identity check.
struct AgentSessionQuitter {
    let policy: ProtectionPolicy
    private let terminator = ProcessTerminator()

    func quit(_ session: AgentSession) async -> String {
        let targets = session.members.filter { policy.hardProtection(for: $0) == nil }
        guard let root = targets.first(where: { $0.pid == session.root.pid }) else {
            return "\(session.kind.rawValue) is protected"
        }
        _ = await terminator.terminate(classified(root))
        await withTaskGroup(of: TerminationResult.self) { group in
            for member in targets where member.pid != root.pid {
                group.addTask { await terminator.terminate(classified(member)) }
            }
        }
        return "Quit \(session.kind.rawValue) in \(session.project) and \(targets.count - 1) processes it started"
    }

    private func classified(_ snapshot: ProcessSnapshot) -> ClassifiedProcess {
        ClassifiedProcess(snapshot: snapshot, cpuPercent: nil, verdict: .normal)
    }
}
