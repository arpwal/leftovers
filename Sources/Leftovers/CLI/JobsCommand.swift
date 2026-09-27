import Foundation

/// `Leftovers --jobs [--json]`: the Scheduled view on the command line, so a
/// Claude Code session can check background jobs before changing them.
enum JobsCommand {
    static let flag = "--jobs"

    struct Row: Encodable {
        let label, title, schedule, program: String
        let loaded, running, addedByClaude: Bool
        let lastExitStatus: Int32?
        let nextRun, endsOn: Date?
        let plist: String
        let log: String?
    }

    static func runIfRequested() {
        guard CommandLine.arguments.contains(flag) else { return }
        let rows = ScheduledStore.readJobs().map {
            Row(label: $0.label, title: $0.title, schedule: JobScheduleText.describe($0.schedule), program: $0.program,
                loaded: $0.isLoaded, running: $0.isRunning, addedByClaude: $0.isFromClaude,
                lastExitStatus: $0.lastExitStatus, nextRun: JobScheduleText.nextRun($0.schedule, lastRun: $0.lastActivity),
                endsOn: $0.metadata?.endsOn, plist: $0.plistPath, log: $0.logPath)
        }
        print(CommandLine.arguments.contains("--json") ? json(rows) : text(rows))
        exit(0)
    }

    private static func json(_ rows: [Row]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(rows)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    private static func text(_ rows: [Row]) -> String {
        rows.map { row in
            let state = !row.loaded ? "off" : row.running ? "running" : (row.lastExitStatus ?? 0) != 0 ? "FAILED" : "waiting"
            let tag = row.addedByClaude ? " [Claude]" : ""
            let next = row.nextRun.map { " · next \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
            return "\(row.title)\(tag)\n  \(row.schedule)\(next) · \(state)\n  \(row.label) → \(row.program)"
        }.joined(separator: "\n\n")
    }
}
