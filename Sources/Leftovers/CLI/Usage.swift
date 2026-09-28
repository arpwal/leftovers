import Foundation

/// The command list, printed by `--help` and after an unknown option.
enum Usage {
    static let text = """
    Leftovers: clean up what your apps and agents left running.

    Usage: Leftovers [command]
      (no command)                 start the app
      --report                     readable memory summary
      --json                       machine-readable memory report
      --clean                      quit every likely leak; protected processes are refused
      --jobs [--json]              scheduled background jobs
      --worktrees [--json]         git worktrees and which are safe to remove
      --disk [--json]              disk split into system, apps and yours, plus developer caches
      --check-updates [--install]  updater state and a check against the live feed
      --snapshot <dir> [--redact]  render the UI to PNGs
      --help                       this text
    """

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n\n\(text)\n".utf8))
        exit(1)
    }
}
