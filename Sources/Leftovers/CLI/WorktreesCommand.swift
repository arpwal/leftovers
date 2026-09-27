import Foundation

/// `Leftovers --worktrees [--json]`: the Worktrees view on the command line.
/// Checks run in parallel; sizes are skipped here to stay fast.
enum WorktreesCommand {
    static let flag = "--worktrees"

    struct Row: Encodable {
        let path, repository, verdict, reason: String
        let branch: String?
        let lastCommit: Date?
        let changes: Int?
        let inUseBy: String?
        let removable: Bool
    }

    static func runIfRequested() {
        guard CommandLine.arguments.contains(flag) else { return }
        let inUse = workingFolders()
        var trees = RepoFinder.repositories(alsoContaining: Array(inUse.keys)).flatMap(WorktreeScanner.list)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: trees.count) { index in
            guard !trees[index].isMain, !trees[index].isPrunable else { return }
            let changes = WorktreeScanner.changes(in: trees[index].path) ?? 0
            lock.lock(); trees[index].changes = changes; lock.unlock()
        }
        let rows = trees.map { tree -> Row in
            var t = tree
            t.inUseBy = WorktreeStore.user(of: t.path, in: inUse)
            t.verdict = WorktreeJudge.verdict(for: t)
            return Row(path: t.path, repository: t.repoRoot, verdict: label(t.verdict), reason: t.verdict.reason,
                       branch: t.branch, lastCommit: t.lastCommit, changes: t.changes, inUseBy: t.inUseBy,
                       removable: t.verdict.canRemove)
        }
        print(CommandLine.arguments.contains("--json") ? json(rows) : text(rows))
        exit(0)
    }

    private static func workingFolders() -> [String: String] {
        var folders: [String: String] = [:]
        for snapshot in ProcessSampler().sample() { if let cwd = snapshot.workingDirectory, cwd != "/" { folders[cwd] = snapshot.name } }
        return folders
    }

    private static func label(_ verdict: WorktreeVerdict) -> String {
        switch verdict {
        case .safe: return "safe"
        case .probablyDone: return "probably_done"
        case .keep: return "keep"
        case .missing: return "missing"
        case .checking: return "unknown"
        }
    }

    private static func json(_ rows: [Row]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(rows)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    private static func text(_ rows: [Row]) -> String {
        let order = ["safe": 0, "probably_done": 1, "missing": 2, "keep": 3, "unknown": 4]
        return rows.sorted { (order[$0.verdict] ?? 9, $0.path) < (order[$1.verdict] ?? 9, $1.path) }.map {
            "[\($0.verdict)] \(($0.path as NSString).lastPathComponent) (\($0.branch ?? "detached")): \($0.reason)"
        }.joined(separator: "\n")
    }
}
