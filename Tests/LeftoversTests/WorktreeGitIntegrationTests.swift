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
        for b in merged dirty active old gone missing squashed squashed-then-more; do \(g) worktree add -q -b $b ../wt-$b; done
        cd ../wt-merged && echo m > m.txt && \(g) add . && \(g) commit -qm merged && cd ../repo && \(g) merge -q merged
        cd ../wt-dirty && echo change >> a.txt
        cd ../wt-active && echo a > a2.txt && \(g) add . && \(g) commit -qm active
        cd ../wt-old && echo o > o.txt && \(g) add . && GIT_COMMITTER_DATE="2026-01-01T12:00:00" \(g) commit -qm old
        cd ../wt-gone && echo g > g.txt && \(g) add . && \(g) commit -qm gone && \(g) push -q -u origin gone && \(g) push -q origin --delete gone && \(g) fetch -q --prune
        rm -rf ../wt-missing
        cd ../wt-squashed && printf 's1\n' > s.txt && \(g) add . && \(g) commit -qm s1 && printf 's2\n' >> s.txt && \(g) commit -qam s2
        cd ../repo && \(g) merge -q --squash squashed && \(g) commit -qm "Squash of squashed (#1)"
        cd ../wt-squashed-then-more && printf 't\n' > t.txt && \(g) add . && \(g) commit -qm t1
        cd ../repo && \(g) merge -q --squash squashed-then-more && \(g) commit -qm "Squash of squashed-then-more (#2)"
        cd ../wt-squashed-then-more && printf 'more\n' > more.txt && \(g) add . && \(g) commit -qm "work after the squash"
        cd ../repo && \(g) push -q origin main
        """, in: root)
        return (root, repo)
    }

    private func verdicts(_ repo: String, inUse: [String: String] = [:]) -> [String: WorktreeVerdict] {
        var result: [String: WorktreeVerdict] = [:]
        for tree in WorktreeScanner.list(repository: repo) {
            result[tree.name] = WorktreePipeline.check(tree, inUse: inUse).verdict
        }
        return result
    }

    @Test func eachSituationGetsTheRightVerdict() throws {
        let (root, repo) = try makeRepository()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let v = verdicts(repo, inUse: ["\(root)/wt-active/src": "Claude Code"])
        #expect(v["repo"] == nil)                                    // main checkout isn't listed
        #expect(v["wt-merged"] == .safe(.alreadyOnMain))             // merged locally, not pushed
        #expect(v["wt-gone"] == .safe(.branchDeleted))
        #expect(v["wt-squashed"] == .safe(.squashMerged))            // two commits squashed into one on main
        #expect(v["wt-squashed-then-more"] == .keep(.notOnMain))     // work added after the squash
        #expect(v["wt-dirty"] == .keep(.changes(1)))
        #expect(v["wt-active"] == .keep(.inUse("Claude Code")))
        #expect(v["wt-missing"] == .missing)
        if case .probablyDone = v["wt-old"] {} else { Issue.record("wt-old: \(String(describing: v["wt-old"]))") }
    }

    @Test func squashCheckNeverWritesToTheRepository() throws {
        let (root, repo) = try makeRepository()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let objects = { try Fixture.sh("git count-objects -v | grep -E '^(count|in-pack):'", in: repo) }
        let before = try objects()
        #expect(SquashMergeCheck.isSquashMerged(branch: "squashed", into: "main", repository: repo))
        #expect(!SquashMergeCheck.isSquashMerged(branch: "squashed-then-more", into: "main", repository: repo))
        #expect(try objects() == before)   // probe commits went to a throwaway folder
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
