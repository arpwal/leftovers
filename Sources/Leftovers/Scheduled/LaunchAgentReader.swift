import Foundation

/// Reads the user's LaunchAgent property lists into `ScheduledJob`s.
struct LaunchAgentReader {
    static let directory = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")

    func jobs(status: [String: LaunchctlStatus.Entry], metadata: JobMetadataStore) -> [ScheduledJob] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: Self.directory)) ?? []
        return files.filter { $0.hasSuffix(".plist") }
            .compactMap { job(at: (Self.directory as NSString).appendingPathComponent($0), status: status, metadata: metadata) }
            .sorted { ($0.isFromClaude ? 0 : 1, $0.label) < ($1.isFromClaude ? 0 : 1, $1.label) }
    }

    private func job(at path: String, status: [String: LaunchctlStatus.Entry], metadata: JobMetadataStore) -> ScheduledJob? {
        guard let plist = NSDictionary(contentsOfFile: path) as? [String: Any],
              let label = plist["Label"] as? String else { return nil }
        let entry = status[label]
        return ScheduledJob(label: label, plistPath: path, program: program(plist), schedule: schedule(plist),
                            logPath: (plist["StandardOutPath"] ?? plist["StandardErrorPath"]) as? String,
                            isLoaded: entry != nil, pid: entry?.pid, lastExitStatus: entry?.lastExitStatus,
                            metadata: metadata.read(label: label))
    }

    private static let interpreters: Set<String> = ["bash", "sh", "zsh", "python", "python3", "node", "ruby", "perl"]

    /// What it runs: the program, or the script when the program is an interpreter.
    private func program(_ plist: [String: Any]) -> String {
        let arguments = plist["ProgramArguments"] as? [String] ?? []
        var runs = (plist["Program"] as? String) ?? arguments.first ?? "—"
        if Self.interpreters.contains((runs as NSString).lastPathComponent), arguments.count > 1 { runs = arguments[1] }
        return runs.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func schedule(_ plist: [String: Any]) -> JobSchedule {
        if let seconds = plist["StartInterval"] as? Int { return .interval(seconds) }
        let raw = plist["StartCalendarInterval"]
        let entries = (raw as? [[String: Int]]) ?? (raw as? [String: Int]).map { [$0] } ?? []
        if !entries.isEmpty {
            return .calendar(entries.map {
                DateComponents(month: $0["Month"], day: $0["Day"], hour: $0["Hour"], minute: $0["Minute"],
                               weekday: $0["Weekday"].map { $0 % 7 + 1 })   // launchd 0/7=Sun → Calendar 1=Sun
            })
        }
        return (plist["RunAtLoad"] as? Bool == true || plist["KeepAlive"] != nil) ? .onLoad : .none
    }
}
