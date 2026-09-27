import Foundation
import Testing
@testable import Leftovers

@Suite("Worktree verdicts")
struct WorktreeJudgeTests {
    private func tree(main: Bool = false, prunable: Bool = false, locked: Bool = false, changes: Int? = 0,
                      merged: Bool = false, squashed: Bool = false, gone: Bool = false,
                      daysSinceCommit: Double = 1, inUse: String? = nil) -> Worktree {
        var t = Worktree(path: "/r/wt", repoRoot: "/r", branch: "b", isMain: main, isLocked: locked, isPrunable: prunable)
        t.changes = changes; t.isMerged = merged; t.isSquashMerged = squashed; t.upstreamGone = gone; t.inUseBy = inUse
        t.lastCommit = Date().addingTimeInterval(-daysSinceCommit * 86_400)
        return t
    }

    @Test func verdictsInPriorityOrder() {
        #expect(WorktreeJudge.verdict(for: tree(main: true, merged: true)) == .keep(.mainCheckout))
        #expect(WorktreeJudge.verdict(for: tree(prunable: true)) == .missing)
        #expect(WorktreeJudge.verdict(for: tree(merged: true, inUse: "Claude Code")) == .keep(.inUse("Claude Code")))
        #expect(WorktreeJudge.verdict(for: tree(changes: nil)) == .checking)
        #expect(WorktreeJudge.verdict(for: tree(changes: 3, merged: true)) == .keep(.changes(3)))
        #expect(WorktreeJudge.verdict(for: tree(locked: true, merged: true)) == .keep(.locked))
        #expect(WorktreeJudge.verdict(for: tree(merged: true)) == .safe(.alreadyOnMain))
        #expect(WorktreeJudge.verdict(for: tree(squashed: true)) == .safe(.squashMerged))
        #expect(WorktreeJudge.verdict(for: tree(gone: true)) == .safe(.branchDeleted))
        #expect(WorktreeJudge.verdict(for: tree(daysSinceCommit: 30)) == .probablyDone(days: 30))
        #expect(WorktreeJudge.verdict(for: tree(daysSinceCommit: 2)) == .keep(.notOnMain))
    }

    @Test func readableReasons() {
        #expect(WorktreeVerdict.safe(.squashMerged).reason == "Squash-merged into main")
        #expect(WorktreeVerdict.keep(.changes(1)).reason == "1 uncommitted change")
        #expect(WorktreeVerdict.keep(.notOnMain).reason == "Not on main yet")
    }

    @Test func everyVerdictFallsInExactlyOneChipSoCountsAddUp() {
        let verdicts: [WorktreeVerdict] = [.safe(.alreadyOnMain), .safe(.squashMerged), .safe(.branchDeleted),
                                           .probablyDone(days: 20), .keep(.inUse("x")), .keep(.changes(2)),
                                           .keep(.locked), .keep(.notOnMain), .missing, .checking]
        let perChip = WorktreeCategory.allCases.map { category in verdicts.filter { $0.category == category }.count }
        #expect(perChip.reduce(0, +) == verdicts.count)
        #expect(verdicts.filter { $0.category == .safe }.count == 3)
        #expect(verdicts.filter(\.canRemove).map(\.category).allSatisfy { $0 == .safe || $0 == .probablyDone })
    }

    @Test func inUseMeansInsideTheFolderNotBesideIt() {
        let inUse = ["/code/wt-1/sub": "node", "/code/wt-10": "Claude Code"]
        #expect(WorktreeStore.user(of: "/code/wt-1", in: inUse) == "node")
        #expect(WorktreeStore.user(of: "/code/wt-10", in: inUse) == "Claude Code")
        #expect(WorktreeStore.user(of: "/code/wt-2", in: inUse) == nil)
        #expect(WorktreeStore.user(of: "/code/wt", in: ["/code/wt-1": "node"]) == nil)   // sibling prefix
    }

    @Test func lastScanIsShownStaleUntilRechecked() {
        var old = tree(merged: true); old.verdict = .safe(.alreadyOnMain); old.sizeBytes = 42
        let fresh = WorktreePipeline.carryOver(from: old, into: tree(changes: nil))
        #expect(fresh.isStale && fresh.verdict == .safe(.alreadyOnMain) && fresh.sizeBytes == 42)
        let rechecked = WorktreePipeline.check(tree(prunable: true), inUse: [:])
        #expect(!rechecked.isStale && rechecked.verdict == .missing)
    }

    @Test func cacheRoundTrip() throws {
        var cache = WorktreeCache()
        cache.url = URL(fileURLWithPath: Fixture.temporaryDirectory()).appendingPathComponent("cache.json")
        var saved = tree(squashed: true); saved.verdict = .safe(.squashMerged); saved.sizeBytes = 7
        cache.save([saved], scannedAt: Date(timeIntervalSince1970: 1_000))
        let loaded = try #require(cache.load())
        #expect(loaded.worktrees.count == 1 && loaded.worktrees[0].verdict == .safe(.squashMerged))
        #expect(loaded.worktrees[0].isStale)   // shown as "refreshing" until re-checked
        #expect(loaded.scannedAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test func sortKeysPutUnknownsLast() {
        var unknown = tree(); unknown.lastCommit = nil
        #expect(unknown.sortLastCommit == .distantPast && unknown.sortSize == 0)
        var safe = tree(); safe.verdict = .safe(.alreadyOnMain)
        var keep = tree(); keep.verdict = .keep(.notOnMain)
        #expect(safe.sortStatus < keep.sortStatus)   // safe ones first by default
    }
}
