import Foundation

/// `--clean`: quits every likely leak, one line of output per process.
/// Uses the same `ProcessTerminator`, so protected processes are refused.
enum CleanCommand {
    static func run(_ report: MemoryReport) async -> String {
        let suspects = report.processes.filter { $0.verdict.isSuspect }
        guard !suspects.isEmpty else { return "No likely leaks. Nothing quit." }
        let terminator = ProcessTerminator()
        var lines: [String] = []
        for process in suspects {
            let result = await terminator.terminate(process)
            lines.append("\(process.snapshot.pid) \(process.snapshot.name) \(Format.bytes(process.snapshot.footprintBytes)): \(result.message)")
        }
        let freed = suspects.reduce(UInt64(0)) { $0 + $1.snapshot.footprintBytes }
        lines.append("Freed about \(Format.bytes(freed)).")
        return lines.joined(separator: "\n")
    }
}
