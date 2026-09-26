import Darwin

/// Answers "has this process been abandoned by whatever started it?"
///
/// A dev server started in a terminal has the terminal somewhere up its parent
/// chain. When that terminal/agent dies, the orphaned dev process is
/// reparented to launchd (pid 1) and nobody will ever stop it — that is a leak.
///
/// Conservative by design: any doubt resolves to "attached".
struct AncestryIndex {
    private let byPid: [pid_t: ProcessSnapshot]
    private static let maxDepth = 64

    init(_ snapshots: [ProcessSnapshot]) {
        byPid = Dictionary(snapshots.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Detached only when the whole chain is visible, no ancestor is an app
    /// (terminal, IDE, desktop app), and the process launchd adopted — the
    /// chain's root — is itself a dev runtime (i.e. an orphan, not a service
    /// launchd started on purpose).
    func isDetached(_ snapshot: ProcessSnapshot, isDevRuntime: (ProcessSnapshot) -> Bool) -> Bool {
        var current = snapshot
        for _ in 0..<Self.maxDepth {
            if current.kind == .appBundle { return false }
            if current.ppid <= 1 { return isDevRuntime(current) }
            // Ancestor we cannot read (e.g. setuid `/usr/bin/login` inside
            // iTerm2): we cannot prove abandonment, so do not flag.
            guard let parent = byPid[current.ppid] else { return false }
            current = parent
        }
        return false
    }
}
