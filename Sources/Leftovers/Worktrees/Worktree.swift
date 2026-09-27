import Foundation

/// Why a worktree is safe to remove: everything in it is already on main.
enum SafeReason: String, Codable, Hashable {
    case alreadyOnMain      // merged, or never had its own commits
    case squashMerged       // squash-merged (e.g. GitHub "Squash and merge")
    case branchDeleted      // its branch was deleted on the remote after merging
}

/// Why a worktree must stay.
enum KeepReason: Codable, Hashable {
    case mainCheckout
    case inUse(String)
    case changes(Int)
    case locked
    case notOnMain
}

/// Whether a worktree can go, and why. Only `.safe` is included in bulk cleanup.
enum WorktreeVerdict: Codable, Hashable {
    case safe(SafeReason)
    case probablyDone(days: Int)   // not on main, but quiet for weeks and clean
    case keep(KeepReason)
    case missing                   // folder deleted; git still lists it (prune)
    case checking

    var reason: String {
        switch self {
        case .safe(.alreadyOnMain): return "Already on main"
        case .safe(.squashMerged): return "Squash-merged into main"
        case .safe(.branchDeleted): return "Branch deleted on GitHub"
        case let .probablyDone(days): return "No commits in \(days) days"
        case .keep(.mainCheckout): return "Main checkout"
        case let .keep(.inUse(user)): return "In use by \(user)"
        case let .keep(.changes(n)): return "\(n) uncommitted change\(n == 1 ? "" : "s")"
        case .keep(.locked): return "Locked"
        case .keep(.notOnMain): return "Not on main yet"
        case .missing: return "Folder is gone; git still lists it"
        case .checking: return "Checking…"
        }
    }

    var canRemove: Bool {
        switch self { case .safe, .probablyDone: return true; default: return false }
    }

    var category: WorktreeCategory {
        switch self {
        case .safe: return .safe
        case .probablyDone: return .probablyDone
        case .keep(.changes): return .hasChanges
        case .keep(.inUse), .keep(.locked), .keep(.mainCheckout): return .inUse
        case .keep(.notOnMain): return .notOnMain
        case .missing: return .missing
        case .checking: return .checking
        }
    }
}

/// The chips above the table. Every worktree is in exactly one, so the
/// counts always add up to the total.
enum WorktreeCategory: String, CaseIterable, Identifiable {
    case safe = "Safe to remove"
    case probablyDone = "Probably done"
    case hasChanges = "Has changes"
    case inUse = "In use"
    case notOnMain = "Not on main yet"
    case missing = "Missing"
    case checking = "Checking"

    var id: String { rawValue }
}

/// One git worktree, filled in progressively: listing first, then status, then size.
struct Worktree: Identifiable, Hashable, Codable {
    let path: String
    let repoRoot: String
    let branch: String?
    let isMain: Bool
    let isLocked: Bool
    let isPrunable: Bool
    var lastCommit: Date?
    var isMerged = false
    var isSquashMerged = false
    var upstreamGone = false
    /// The branch "on main" is judged against (origin/main when there is one).
    var mainRef = "main"
    var changes: Int?          // nil until checked
    var inUseBy: String?
    var sizeBytes: UInt64?     // nil until measured
    var verdict: WorktreeVerdict = .checking
    /// Shown from the last scan while this one re-checks it.
    var isStale = false

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var repoName: String { (repoRoot as NSString).lastPathComponent }

    // Sort keys for table columns (optionals sort last).
    var sortStatus: Int { WorktreeCategory.allCases.firstIndex(of: verdict.category) ?? 99 }
    var sortLastCommit: Date { lastCommit ?? .distantPast }
    var sortSize: UInt64 { sizeBytes ?? 0 }
}

/// Decides a worktree's verdict from what the scanner found.
enum WorktreeJudge {
    static let quietDays = 14

    static func verdict(for tree: Worktree, now: Date = Date()) -> WorktreeVerdict {
        if tree.isMain { return .keep(.mainCheckout) }   // never listed, never removable
        if tree.isPrunable { return .missing }
        if let user = tree.inUseBy { return .keep(.inUse(user)) }
        guard let changes = tree.changes else { return .checking }
        if changes > 0 { return .keep(.changes(changes)) }
        if tree.isLocked { return .keep(.locked) }
        if tree.isMerged { return .safe(.alreadyOnMain) }
        if tree.isSquashMerged { return .safe(.squashMerged) }
        if tree.upstreamGone { return .safe(.branchDeleted) }
        if let last = tree.lastCommit, let days = Calendar.current.dateComponents([.day], from: last, to: now).day,
           days >= quietDays { return .probablyDone(days: days) }
        return .keep(.notOnMain)
    }
}
