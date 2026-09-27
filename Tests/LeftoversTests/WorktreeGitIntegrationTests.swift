import Foundation
import Testing
@testable import Leftovers

/// Runs against real git: builds a throwaway repository with one worktree per
/// situation and checks what Leftovers concludes about each, plus the safety
/// promise that a worktree with uncommitted work is never removed.
@Suite("Worktrees against real git", .serialized)
struct WorktreeGitIntegrationTests {
    private static let git = "git -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false -c init.defaultBranch=main"

    /// root/remote.git (bare), root/repo (main), root/wt-* (linked worktrees)
    private func makeRepository() throws -> (root: String, repo: String) {
        let root = Fixture.temporaryDirectory(), repo = "\(root)/repo", g = Self.git
        try Fixture.sh("""
        \(g) init -q --bare remote.git && \(g) init -q repo && cd repo && echo hi > a.txt && \(g) add . && \(g) commit -qm init
        \(g) remote add origin ../remote.git && \(g) push -q -u origin main
        for b in merged dirty active old gone missing; do \(g) worktree add -q -b $b ../wt-$b; done
        cd ../wt-merged && echo m > m.txt && \(g) add . && \(g) commit -qm merged && cd ../repo && \(g) merge -q merged
        cd ../wt-dirty && echo change >> a.txt
        cd ../wt-active && echo a > a2.txt && \(g) add . && \(g) commit -qm active
        cd ../wt-old && echo o > o.txt && \(g) add . && GIT_COMMITTER_DATE="2026-01-01T12:00:00" \(g) commit -qm old
        cd ../wt-gone && echo g > g.txt && \(g) add . && \(g) commit -qm gone && \(g) push -q -u origin gone && \(g) push -q origin --delete gone && \(g) fetch -q --prune
        rm -rf ../wt-missing
        """, in: root)
        return (root, repo)
    }

    private func verdicts(_ repo: String, inUse: [String: String] = [:]) -> [String: WorktreeVerdict] {
        var result: [String: WorktreeVerdict] = [:]
        for var tree in WorktreeScanner.list(repository: repo) {
            if !tree.isMain && !tree.isPrunable { tree.changes = WorktreeScanner.changes(in: tree.path) }
            tree.inUseBy = WorktreeStore.user(of: tree.path, in: inUse)
            result[tree.name] = WorktreeJudge.verdict(for: tree)
        }
        return result
    }

    @Test func eachSituationGetsTheRightVerdict() throws {
        let (root, repo) = try makeRepository()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let v = verdicts(repo, inUse: ["\(root)/wt-active/src": "Claude Code"])
        #expect(v["repo"] == .keep("Main checkout"))
        #expect(v["wt-merged"] == .safe("Already on main"))        // merged locally, not pushed
        #expect(v["wt-gone"] == .safe("Branch deleted on GitHub"))
        #expect(v["wt-dirty"] == .keep("1 uncommitted change"))
        #expect(v["wt-active"] == .keep("In use by Claude Code"))
        #expect(v["wt-missing"] == .missing)
        if case .probablyDone = v["wt-old"] {} else { Issue.record("wt-old: \(String(describing: v["wt-old"]))") }
    }

    @Test func gitRefusesToRemoveUncommittedWorkAndRemovesMergedOnes() throws {
        let (root, repo) = try makeRepository()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let dirty = Git.runWithError(["worktree", "remove", "\(root)/wt-dirty"], in: repo)
        #expect(!dirty.ok)
        #expect(FileManager.default.fileExists(atPath: "\(root)/wt-dirty/a.txt"))   // work is still there

        let merged = Git.runWithError(["worktree", "remove", "\(root)/wt-merged"], in: repo)
        #expect(merged.ok)
        #expect(!FileManager.default.fileExists(atPath: "\(root)/wt-merged"))
        #expect(Git.run(["branch", "--list", "merged"], in: repo)?.contains("merged") == true)   // branch kept
    }

    @Test func pruneClearsMissingWorktrees() throws {
        let (root, repo) = try makeRepository()
        defer { try? FileManager.default.removeItem(atPath: root) }
        #expect(verdicts(repo)["wt-missing"] == .missing)
        _ = Git.runWithError(["worktree", "prune"], in: repo)
        #expect(verdicts(repo)["wt-missing"] == nil)
    }
}
