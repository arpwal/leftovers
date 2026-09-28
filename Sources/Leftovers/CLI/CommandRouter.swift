import Foundation

/// Decides what one invocation does, from its arguments alone. A single
/// decision point means a modifier like `--json` can't be picked up by the
/// wrong command (it used to turn `--worktrees --json` into the memory report).
enum CommandRouter {
    enum Command: Equatable {
        case app
        case help
        case unknown(String)
        case missingValue(String)
        case memoryReport, memoryJSON, clean
        case jobs(json: Bool)
        case worktrees(json: Bool)
        case disk(json: Bool)
        case checkUpdates(install: Bool)
        case snapshot(directory: String, redact: Bool)
    }

    static let flags: Set<String> = ["--report", "--json", "--clean", "--jobs", "--worktrees", "--disk", "--check-updates",
                                     "--install", "--snapshot", "--redact", "--help", "-h"]

    static func command(for arguments: [String]) -> Command {
        // macOS may add launch arguments such as -psn_0_123 or -NSDocumentRevisionsDebugMode YES.
        let args = Array(arguments.dropFirst())
        let has = { (flag: String) in args.contains(flag) }
        if has("--help") || has("-h") { return .help }
        if let unknown = args.first(where: { $0.hasPrefix("--") && !flags.contains($0) }) { return .unknown(unknown) }

        // Commands first, then the modifiers that belong to them.
        if has("--snapshot") {
            guard let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count,
                  !args[index + 1].hasPrefix("--") else { return .missingValue("--snapshot") }
            return .snapshot(directory: args[index + 1], redact: has("--redact"))
        }
        if has("--jobs") { return .jobs(json: has("--json")) }
        if has("--worktrees") { return .worktrees(json: has("--json")) }
        if has("--disk") { return .disk(json: has("--json")) }
        if has("--check-updates") { return .checkUpdates(install: has("--install")) }
        if has("--clean") { return .clean }
        if has("--report") { return .memoryReport }
        if has("--json") { return .memoryJSON }
        return .app
    }
}
