import Foundation

/// The Worktrees section's data. Shows the last scan instantly, then runs
/// one live pipeline: repositories are found, every worktree is listed, and
/// status checks and size measurements run at the same time (8 in flight),
/// each result landing in the table as soon as it's ready.
@MainActor
final class WorktreeStore: ObservableObject {
    struct Progress: Equatable {
        var isFinding = false
        var repositories = 0
        var total = 0
        var checked = 0
        var measured = 0
        var isScanning: Bool { isFinding || checked < total || measured < total }
    }

    static let shared = WorktreeStore()
    @Published private(set) var worktrees: [Worktree] = []
    @Published private(set) var progress = Progress()
    @Published private(set) var lastScan: Date?
    @Published var lastActionMessage: String?
    private let cache = WorktreeCache()
    private static let inFlight = 8, sizesInFlight = 3

    init() {
        if let cached = cache.load() { worktrees = cached.worktrees; lastScan = cached.scannedAt }
    }

    var safe: [Worktree] { worktrees.filter { $0.verdict.category == .safe && !$0.isStale } }
    var reclaimableBytes: UInt64 { worktrees.filter(\.verdict.canRemove).compactMap(\.sizeBytes).reduce(0, +) }
    func count(_ category: WorktreeCategory) -> Int { worktrees.filter { $0.verdict.category == category }.count }

    /// `inUse` maps a working folder to who is using it ("Claude Code", "node").
    func scan(inUse: [String: String]) async {
        guard !progress.isScanning else { return }
        progress = Progress(isFinding: true)
        let (repos, listed) = await Task.detached(priority: .userInitiated) {
            let repos = RepoFinder.repositories(alsoContaining: Array(inUse.keys))
            return (repos.count, repos.flatMap(WorktreeScanner.list))
        }.value
        let previous = Dictionary(worktrees.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        worktrees = listed.map { WorktreePipeline.carryOver(from: previous[$0.path], into: $0) }
        progress = Progress(isFinding: false, repositories: repos, total: listed.count)
        await WorktreePipeline.run(listed, inUse: inUse, inFlight: Self.inFlight, sizesInFlight: Self.sizesInFlight) { event in
            switch event {
            case let .checked(tree): self.replace(tree); self.progress.checked += 1
            case let .measured(path, size): self.update(path) { $0.sizeBytes = size }; self.progress.measured += 1
            }
        }
        lastScan = Date()
        cache.save(worktrees, scannedAt: lastScan ?? Date())
    }

    func forget(_ path: String) {
        worktrees.removeAll { $0.path == path }
        cache.save(worktrees, scannedAt: lastScan ?? Date())
    }

    private func replace(_ tree: Worktree) {
        guard let index = worktrees.firstIndex(where: { $0.path == tree.path }) else { return }
        var fresh = tree
        fresh.sizeBytes = fresh.sizeBytes ?? worktrees[index].sizeBytes   // keep a known size until re-measured
        worktrees[index] = fresh
    }

    private func update(_ path: String, _ change: (inout Worktree) -> Void) {
        guard let index = worktrees.firstIndex(where: { $0.path == path }) else { return }
        change(&worktrees[index])
    }

    nonisolated static func user(of path: String, in inUse: [String: String]) -> String? {
        inUse.first { $0.key == path || $0.key.hasPrefix(path + "/") }?.value
    }
}
