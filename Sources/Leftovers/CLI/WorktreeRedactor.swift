import Foundation

/// Generic names for worktrees, branches and repositories in public
/// screenshots (real ones are often private ticket or project names).
enum WorktreeRedactor {
    private static let names = ["add-login", "fix-crash-on-launch", "new-onboarding", "speed-up-search", "dark-mode",
                                "billing-page", "api-retries", "cleanup-logs", "export-csv", "push-notifications",
                                "settings-redesign", "offline-mode", "image-cache", "sso", "rate-limits", "audit-log"]
    private static let repos = ["web-app", "api", "mobile"]

    static func redact(_ trees: [Worktree]) -> [Worktree] {
        var repoAlias: [String: String] = [:]
        return trees.enumerated().map { index, tree in
            let name = names[index % names.count] + (index >= names.count ? "-\(index / names.count + 1)" : "")
            let repo = repoAlias[tree.repoRoot] ?? repos[repoAlias.count % repos.count]
            repoAlias[tree.repoRoot] = repo
            var redacted = Worktree(path: "/code/\(repo)/worktrees/\(name)", repoRoot: "/code/\(repo)", branch: name,
                                    isMain: tree.isMain, isLocked: tree.isLocked, isPrunable: tree.isPrunable)
            redacted.lastCommit = tree.lastCommit
            redacted.changes = tree.changes
            redacted.sizeBytes = tree.sizeBytes
            redacted.verdict = tree.verdict   // process names like "node" or "zsh" aren't private
            return redacted
        }
    }
}
