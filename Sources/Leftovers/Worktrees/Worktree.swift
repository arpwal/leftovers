import Foundation

/// Whether a worktree can go, and why. Only `.safe` is included in bulk cleanup.
enum WorktreeVerdict: Hashable {
    case safe(String)          // merged or branch deleted, clean, unused
    case probablyDone(String)  // quiet for a long time, clean, unused
    case keep(String)          // changes, in use, locked, main checkout, or still active
    case missing               // folder deleted; git still lists it (prune)
    case checking

    var reason: String {
        switch self {
        case let .safe(r), let .probablyDone(r), let .keep(r): return r
        case .missing: return "Folder is gone; git still lists it"
        case .checking: return "Checking…"
        }
    }

    var canRemove: Bool {
        switch self { case .safe, .probablyDone: return true; default: return false }
    }
}

/// One git worktree, filled in progressively: listing first, then status, then size.
struct Worktree: Identifiable, Hashable {
    let path: String
    let repoRoot: String
    let branch: String?
    let isMain: Bool
    let isLocked: Bool
    let isPrunable: Bool
    var lastCommit: Date?
    var isMerged = false
    var upstreamGone = false
    var changes: Int?          // nil until checked
    var inUseBy: String?
    var sizeBytes: UInt64?     // nil until measured
    var verdict: WorktreeVerdict = .checking

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var repoName: String { (repoRoot as NSString).lastPathComponent }
}

/// Decides a worktree's verdict from what the scanner found.
enum WorktreeJudge {
    static let quietDays = 14

    static func verdict(for tree: Worktree, now: Date = Date()) -> WorktreeVerdict {
        if tree.isMain { return .keep("Main checkout") }
        if tree.isPrunable { return .missing }
        if let user = tree.inUseBy { return .keep("In use by \(user)") }
        guard let changes = tree.changes else { return .checking }
        if changes > 0 { return .keep("\(changes) uncommitted change\(changes == 1 ? "" : "s")") }
        if tree.isLocked { return .keep("Locked") }
        if tree.isMerged { return .safe("Already on main") }   // merged, or never had its own commits
        if tree.upstreamGone { return .safe("Branch deleted on GitHub") }
        if let last = tree.lastCommit, let days = Calendar.current.dateComponents([.day], from: last, to: now).day,
           days >= quietDays { return .probablyDone("No commits in \(days) days") }
        return .keep("Active")
    }
}
