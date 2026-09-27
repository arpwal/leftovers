import Foundation

/// The Worktrees section's data, filled progressively: the list appears at
/// once, then each worktree's status, then sizes, eight checks at a time,
/// all off the main thread.
@MainActor
final class WorktreeStore: ObservableObject {
    enum Phase: Equatable { case idle, finding, checking(done: Int, total: Int), measuring(done: Int, total: Int), done }

    static let shared = WorktreeStore()
    @Published private(set) var worktrees: [Worktree] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastScan: Date?
    @Published var lastActionMessage: String?
    private static let parallelism = 8

    var safe: [Worktree] { worktrees.filter { if case .safe = $0.verdict { return true } else { return false } } }
    var missingCount: Int { worktrees.filter { $0.verdict == .missing }.count }
    var reclaimableBytes: UInt64 { worktrees.filter { $0.verdict.canRemove }.compactMap(\.sizeBytes).reduce(0, +) }

    /// `inUse` maps a working folder to who is using it ("Claude Code", "node").
    func scan(inUse: [String: String]) async {
        guard phase == .idle || phase == .done else { return }
        phase = .finding
        let lists = await Task.detached(priority: .userInitiated) {
            RepoFinder.repositories(alsoContaining: Array(inUse.keys)).flatMap(WorktreeScanner.list)
        }.value
        worktrees = lists.map { tree in var t = tree; t.inUseBy = Self.user(of: t.path, in: inUse); t.verdict = WorktreeJudge.verdict(for: t); return t }
        await check(inUse: inUse)
        await measure()
        phase = .done
        lastScan = Date()
    }

    private func check(inUse: [String: String]) async {
        let pending = worktrees.filter { $0.verdict == .checking }.map(\.path)
        var done = 0
        phase = .checking(done: 0, total: pending.count)
        await Self.forEach(pending, limit: Self.parallelism, work: { WorktreeScanner.changes(in: $0) }) { path, changes in
            update(path) { $0.changes = changes ?? 0; $0.verdict = WorktreeJudge.verdict(for: $0) }
            done += 1
            phase = .checking(done: done, total: pending.count)
        }
    }

    /// Sizes for removable worktrees first: that's what cleanup frees.
    private func measure() async {
        let order = worktrees.filter { !$0.isMain && !$0.isPrunable }
            .sorted { ($0.verdict.canRemove ? 0 : 1) < ($1.verdict.canRemove ? 0 : 1) }.map(\.path)
        var done = 0
        phase = .measuring(done: 0, total: order.count)
        await Self.forEach(order, limit: 4, work: { Git.size(of: $0) }) { path, size in
            update(path) { $0.sizeBytes = size }
            done += 1
            phase = .measuring(done: done, total: order.count)
        }
    }

    func forget(_ path: String) { worktrees.removeAll { $0.path == path } }

    private func update(_ path: String, _ change: (inout Worktree) -> Void) {
        guard let index = worktrees.firstIndex(where: { $0.path == path }) else { return }
        change(&worktrees[index])
    }

    nonisolated static func user(of path: String, in inUse: [String: String]) -> String? {
        inUse.first { $0.key == path || $0.key.hasPrefix(path + "/") }?.value
    }

    /// Runs `work` on each item off the main thread, at most `limit` at once,
    /// delivering each result on the main actor as soon as it finishes.
    private static func forEach<R: Sendable>(_ items: [String], limit: Int, work: @escaping @Sendable (String) -> R,
                                             deliver: @MainActor (String, R) -> Void) async {
        await withTaskGroup(of: (String, R).self) { group in
            var next = items.makeIterator()
            for _ in 0..<limit { if let item = next.next() { group.addTask { (item, work(item)) } } }
            for await (item, result) in group {
                deliver(item, result)
                if let item = next.next() { group.addTask { (item, work(item)) } }
            }
        }
    }
}
