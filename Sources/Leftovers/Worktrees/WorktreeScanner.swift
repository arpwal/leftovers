import Foundation

/// Reads worktrees from git. Listing is one command per repository; the
/// per-worktree checks (status, size) are separate so callers can run them
/// in parallel and show results as they arrive.
enum WorktreeScanner {
    /// All worktrees of one repository, with branch facts filled in.
    static func list(repository: String) -> [Worktree] {
        guard let porcelain = Git.run(["worktree", "list", "--porcelain"], in: repository) else { return [] }
        let branches = BranchFacts.read(repository: repository)
        return porcelain.components(separatedBy: "\n\n").enumerated().compactMap { index, block in
            parse(block, repository: repository, isMain: index == 0, branches: branches)
        }
    }

    /// `git status` on one worktree: the number of changed or untracked files.
    static func changes(in path: String) -> Int? {
        Git.run(["status", "--porcelain"], in: path, timeout: 20)
            .map { $0.split(separator: "\n").count }
    }

    private static func parse(_ block: String, repository: String, isMain: Bool, branches: BranchFacts) -> Worktree? {
        var path: String?, branch: String?, locked = false, prunable = false
        for line in block.split(separator: "\n") {
            if line.hasPrefix("worktree ") { path = String(line.dropFirst(9)) }
            if line.hasPrefix("branch refs/heads/") { branch = String(line.dropFirst(18)) }
            if line.hasPrefix("locked") { locked = true }
            if line.hasPrefix("prunable") { prunable = true }
        }
        guard let path else { return nil }
        var tree = Worktree(path: path, repoRoot: repository, branch: branch, isMain: isMain,
                            isLocked: locked, isPrunable: prunable)
        if let branch {
            tree.lastCommit = branches.lastCommit[branch]
            tree.isMerged = branches.merged.contains(branch)
            tree.upstreamGone = branches.gone.contains(branch)
        }
        return tree
    }
}

/// Per-branch facts for a whole repository, in three quick git calls.
struct BranchFacts {
    var lastCommit: [String: Date] = [:]
    var merged: Set<String> = []
    var gone: Set<String> = []

    static func read(repository: String) -> BranchFacts {
        var facts = BranchFacts()
        let refs = Git.run(["for-each-ref", "--format=%(refname:short)|%(committerdate:unix)|%(upstream:track)", "refs/heads"],
                           in: repository) ?? ""
        for line in refs.split(separator: "\n") {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { continue }
            if let seconds = TimeInterval(parts[1]) { facts.lastCommit[parts[0]] = Date(timeIntervalSince1970: seconds) }
            if parts[2] == "[gone]" { facts.gone.insert(parts[0]) }
        }
        // "On main" means on the local main branch OR the remote one: a merge
        // that isn't pushed yet still counts, and so does one made on GitHub.
        let remoteMain = Git.run(["symbolic-ref", "--short", "refs/remotes/origin/HEAD"], in: repository)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let localMain = ((remoteMain ?? "main") as NSString).lastPathComponent
        for target in [remoteMain, localMain].compactMap({ $0 }) {
            let merged = Git.run(["branch", "--merged", target, "--format=%(refname:short)"], in: repository) ?? ""
            facts.merged.formUnion(merged.split(separator: "\n").map(String.init))
        }
        facts.merged.remove(localMain)   // the main branch itself isn't "merged"
        return facts
    }
}
