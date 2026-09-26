import Foundation

/// Makes a report safe for public screenshots: paths under the home folder
/// collapse to `~/…/<name>`, project folders get generic names, and anything
/// mentioning a private name is dropped.
struct ReportRedactor {
    private let home = NSHomeDirectory()
    private let privateTerms: [String]
    private static let aliases = ["website", "api", "mobile-app", "docs", "infra", "design-system", "data-pipeline", "cli"]
    private var projects: [String: String] = [:]

    init(privateTerms: [String]) {
        self.privateTerms = privateTerms.map { $0.lowercased() }
    }

    mutating func redact(_ report: MemoryReport) -> MemoryReport {
        var processes: [ClassifiedProcess] = []
        for process in report.processes where !isPrivate(process.snapshot) { processes.append(redact(process)) }
        var agents: [AgentSession] = []
        for session in report.agents {
            var members: [ProcessSnapshot] = []
            for member in session.members where !isPrivate(member) { members.append(redact(member)) }
            agents.append(AgentSession(kind: session.kind, root: redact(session.root),
                                       members: members, toolServers: session.toolServers))
        }
        agents.sort { $0.totalFootprint > $1.totalFootprint }
        return MemoryReport(system: report.system, processes: processes, agents: agents,
                            duplicateToolServers: report.duplicateToolServers, takenAt: report.takenAt)
    }

    private func isPrivate(_ snapshot: ProcessSnapshot) -> Bool {
        let haystack = (snapshot.executablePath + " " + snapshot.name).lowercased()
        return privateTerms.contains { haystack.contains($0) }
    }

    private mutating func redact(_ process: ClassifiedProcess) -> ClassifiedProcess {
        let verdict: ProcessVerdict
        if case let .suspect(.workingDirectoryDeleted(path)) = process.verdict {
            verdict = .suspect(.workingDirectoryDeleted(path: redactPath(path)))
        } else {
            verdict = process.verdict
        }
        return ClassifiedProcess(snapshot: redact(process.snapshot), cpuPercent: process.cpuPercent, verdict: verdict)
    }

    private mutating func redact(_ s: ProcessSnapshot) -> ProcessSnapshot {
        ProcessSnapshot(pid: s.pid, ppid: s.ppid, uid: s.uid, name: s.name, executablePath: redactPath(s.executablePath),
                        workingDirectory: s.workingDirectory.map { alias(for: $0) }, startDate: s.startDate,
                        footprintBytes: s.footprintBytes, residentBytes: s.residentBytes,
                        cpuTimeNanos: s.cpuTimeNanos, kind: s.kind)
    }

    private func redactPath(_ path: String) -> String {
        path.hasPrefix(home) ? "~/…/" + (path as NSString).lastPathComponent : path
    }

    private mutating func alias(for directory: String) -> String {
        if let known = projects[directory] { return known }
        let name = "~/code/" + Self.aliases[projects.count % Self.aliases.count]
        projects[directory] = name
        return name
    }
}
