import Foundation

/// Maps the internal model onto the public JSON contract.
extension JSONReport {
    init(_ report: MemoryReport) {
        let s = report.system
        takenAt = report.takenAt
        system = System(totalBytes: s.totalBytes, swapUsedBytes: s.swapUsedBytes, swapTotalBytes: s.swapTotalBytes,
                        compressedBytes: s.compressedBytes, availablePercent: s.availablePercent,
                        pressure: s.pressure.label.lowercased())
        likelyLeaks = report.processes.filter { $0.verdict.isSuspect }.map(Self.process)
        agents = report.agents.map {
            Agent(agent: $0.kind.rawValue, project: $0.project, workingDirectory: $0.root.workingDirectory,
                  pid: $0.root.pid, footprintBytes: $0.totalFootprint, processCount: $0.members.count,
                  toolServers: $0.toolServers.map(\.name))
        }
        duplicateToolServers = report.duplicateToolServers.map {
            Duplicate(name: $0.name, processCount: $0.processCount, sessionCount: $0.sessionCount,
                      footprintBytes: $0.totalFootprint)
        }
    }

    private static func process(_ p: ClassifiedProcess) -> Process {
        Process(pid: p.snapshot.pid, name: p.snapshot.name, path: p.snapshot.executablePath,
                verdict: p.verdict.isSuspect ? "likely_leak" : (p.verdict.isKillable ? "normal" : "protected"),
                reason: p.verdict.explanation, footprintBytes: p.snapshot.footprintBytes,
                residentBytes: p.snapshot.residentBytes, cpuPercent: p.cpuPercent,
                ageSeconds: Int(p.snapshot.age), killable: p.verdict.isKillable)
    }
}
