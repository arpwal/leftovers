import Foundation

/// Plain-text rendering of a `MemoryReport` for `--report`.
enum TextReport {
    static func render(_ report: MemoryReport) -> String {
        let system = report.system
        var lines = ["Pressure \(system.pressure.label) · \(system.availablePercent)% available · swap \(Format.bytes(system.swapUsedBytes)) of \(Format.bytes(system.swapTotalBytes))"]
        let suspects = report.processes.filter { $0.verdict.isSuspect }
        lines.append("\nLIKELY LEAKS (\(suspects.count))")
        lines += suspects.map(line)
        lines.append("\nAGENTS (\(report.agents.count))")
        lines += report.agents.map {
            "  \($0.kind.rawValue) · \($0.project) · \(Format.bytes($0.totalFootprint)) · \($0.members.count) processes · \($0.toolServers.count) tool servers"
        }
        lines += report.duplicateToolServers.map {
            "  duplicated: \($0.name) ×\($0.processCount) across \($0.sessionCount) sessions, \(Format.bytes($0.totalFootprint))"
        }
        lines.append("\nTOP 10")
        lines += report.processes.prefix(10).map(line)
        return lines.joined(separator: "\n")
    }

    private static func line(_ process: ClassifiedProcess) -> String {
        let tag: String
        switch process.verdict {
        case .protected: tag = "PROTECTED"
        case .suspect: tag = "LEAK"
        case .normal: tag = "ok"
        }
        let s = process.snapshot
        return "  [\(tag)] \(s.pid) \(s.name) \(Format.bytes(s.footprintBytes)) cpu \(Format.cpu(process.cpuPercent)) \(Format.age(s.age)) \(process.verdict.explanation)"
    }
}
