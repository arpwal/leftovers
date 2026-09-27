import Foundation
import Testing
@testable import Leftovers

@Suite("Worktree verdicts")
struct WorktreeJudgeTests {
    private func tree(main: Bool = false, prunable: Bool = false, locked: Bool = false, changes: Int? = 0,
                      merged: Bool = false, gone: Bool = false, daysSinceCommit: Double = 1, inUse: String? = nil) -> Worktree {
        var t = Worktree(path: "/r/wt", repoRoot: "/r", branch: "b", isMain: main, isLocked: locked, isPrunable: prunable)
        t.changes = changes; t.isMerged = merged; t.upstreamGone = gone; t.inUseBy = inUse
        t.lastCommit = Date().addingTimeInterval(-daysSinceCommit * 86_400)
        return t
    }

    @Test func verdictsInPriorityOrder() {
        #expect(WorktreeJudge.verdict(for: tree(main: true, merged: true)) == .keep("Main checkout"))
        #expect(WorktreeJudge.verdict(for: tree(prunable: true)) == .missing)
        #expect(WorktreeJudge.verdict(for: tree(merged: true, inUse: "Claude Code")) == .keep("In use by Claude Code"))
        #expect(WorktreeJudge.verdict(for: tree(changes: nil)) == .checking)
        #expect(WorktreeJudge.verdict(for: tree(changes: 3, merged: true)) == .keep("3 uncommitted changes"))
        #expect(WorktreeJudge.verdict(for: tree(locked: true, merged: true)) == .keep("Locked"))
        #expect(WorktreeJudge.verdict(for: tree(merged: true)) == .safe("Already on main"))
        #expect(WorktreeJudge.verdict(for: tree(gone: true)) == .safe("Branch deleted on GitHub"))
        #expect(WorktreeJudge.verdict(for: tree(daysSinceCommit: 30)) == .probablyDone("No commits in 30 days"))
        #expect(WorktreeJudge.verdict(for: tree(daysSinceCommit: 2)) == .keep("Active"))
    }

    @Test func onlySafeAndProbablyDoneCanBeRemoved() {
        #expect(WorktreeVerdict.safe("x").canRemove && WorktreeVerdict.probablyDone("x").canRemove)
        #expect(!WorktreeVerdict.keep("x").canRemove && !WorktreeVerdict.missing.canRemove && !WorktreeVerdict.checking.canRemove)
    }

    @Test func inUseMeansInsideTheFolderNotBesideIt() {
        let inUse = ["/code/wt-1/sub": "node", "/code/wt-10": "Claude Code"]
        #expect(WorktreeStore.user(of: "/code/wt-1", in: inUse) == "node")
        #expect(WorktreeStore.user(of: "/code/wt-10", in: inUse) == "Claude Code")
        #expect(WorktreeStore.user(of: "/code/wt-2", in: inUse) == nil)
        #expect(WorktreeStore.user(of: "/code/wt", in: ["/code/wt-1": "node"]) == nil)   // sibling prefix
    }
}
