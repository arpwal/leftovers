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

    static func runAndExit(json: Bool) {
        let inUse = workingFolders()
        var trees = RepoFinder.repositories(alsoContaining: Array(inUse.keys)).flatMap(WorktreeScanner.list)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: trees.count) { index in
            let checked = WorktreePipeline.check(trees[index], inUse: inUse)
            lock.lock(); trees[index] = checked; lock.unlock()
        }
        let rows = trees.map { t -> Row in
            Row(path: t.path, repository: t.repoRoot, verdict: label(t.verdict), reason: t.verdict.reason,
                       branch: t.branch, lastCommit: t.lastCommit, changes: t.changes, inUseBy: t.inUseBy,
                       removable: t.verdict.canRemove)
        }
        print(json ? Self.json(rows) : text(rows))
        exit(0)
    }

    private static func workingFolders() -> [String: String] {
        var folders: [String: String] = [:]
        for snapshot in ProcessSampler().sample() { if let cwd = snapshot.workingDirectory, cwd != "/" { folders[cwd] = snapshot.name } }
        return folders
    }

    private static func label(_ verdict: WorktreeVerdict) -> String {
        switch verdict.category {
        case .safe: return "safe"
        case .probablyDone: return "probably_done"
        case .hasChanges: return "has_changes"
        case .inUse: return "in_use"
        case .notOnMain: return "not_on_main"
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
        let order = ["safe": 0, "probably_done": 1, "missing": 2, "has_changes": 3, "in_use": 4, "not_on_main": 5, "unknown": 6]
        return rows.sorted { (order[$0.verdict] ?? 9, $0.path) < (order[$1.verdict] ?? 9, $1.path) }.map {
            "[\($0.verdict)] \(($0.path as NSString).lastPathComponent) (\($0.branch ?? "detached")): \($0.reason)"
        }.joined(separator: "\n")
    }
}
