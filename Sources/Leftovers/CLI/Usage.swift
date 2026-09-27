import Foundation

/// `--help`, and a guard so an unknown flag prints this instead of starting a
/// second copy of the app.
enum Usage {
    static let text = """
    Leftovers: clean up what your apps and agents left running.

    Usage: Leftovers [command]
      (no command)               start the menu-bar app
      --report                   readable memory summary
      --json                     machine-readable report (likelyLeaks, agents, duplicateToolServers)
      --clean                    quit every likely leak; protected processes are refused
      --jobs [--json]            scheduled background jobs
      --worktrees [--json]       git worktrees and which are safe to remove
      --check-updates [--install] updater state and a check against the live feed
      --snapshot <dir> [--redact] render the UI to PNGs
      --help                     this text
    """

    /// Flags that take a value, so the value isn't mistaken for a flag.
    private static let known: Set<String> = ["--report", "--json", "--clean", "--jobs", "--worktrees",
                                             "--check-updates", "--install", "--snapshot", "--redact", "--help", "-h"]

    static func handleHelpAndUnknownFlags() {
        let arguments = CommandLine.arguments.dropFirst()
        if arguments.contains("--help") || arguments.contains("-h") { print(text); exit(0) }
        // macOS may pass -psn_… or -NSDocumentRevisionsDebugMode when launching from Finder/Xcode.
        let unknown = arguments.filter { $0.hasPrefix("--") && !known.contains($0) }
        if let flag = unknown.first {
            FileHandle.standardError.write(Data("Unknown option \(flag)\n\n\(text)\n".utf8))
            exit(1)
        }
    }
}
