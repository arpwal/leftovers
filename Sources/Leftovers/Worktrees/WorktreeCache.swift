import Foundation

/// The last scan, saved so the Worktrees view appears instantly next time
/// (marked as refreshing until the new scan re-checks each row).
struct WorktreeCache {
    var url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Leftovers/worktrees-cache.json")

    private struct Snapshot: Codable {
        let scannedAt: Date
        let worktrees: [Worktree]
    }

    func load() -> (worktrees: [Worktree], scannedAt: Date)? {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        return (snapshot.worktrees.map { var t = $0; t.isStale = true; return t }, snapshot.scannedAt)
    }

    func save(_ worktrees: [Worktree], scannedAt: Date) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(Snapshot(scannedAt: scannedAt, worktrees: worktrees)).write(to: url, options: .atomic)
    }
}
