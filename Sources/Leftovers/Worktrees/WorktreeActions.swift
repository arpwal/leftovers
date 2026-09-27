import AppKit

/// Removing and pruning worktrees. Always `git worktree remove` without
/// `--force`: git itself refuses if there are uncommitted or untracked
/// files, so work can't be lost. The branch is kept.
@MainActor
enum WorktreeActions {
    /// `inUse` is checked again right now: something may have started
    /// working in the folder since the scan.
    static func remove(_ tree: Worktree, store: WorktreeStore, inUse: [String: String]) async -> Bool {
        if let user = WorktreeStore.user(of: tree.path, in: inUse) {
            store.lastActionMessage = "Kept \(tree.name): \(user) is working in it right now."
            return false
        }
        let result = await Task.detached { Git.runWithError(["worktree", "remove", tree.path], in: tree.repoRoot) }.value
        if result.ok { store.forget(tree.path) }
        store.lastActionMessage = result.ok ? "Removed \(tree.name). Its branch \(tree.branch ?? "") is kept."
                                            : "Git kept \(tree.name): \(result.message)"
        return result.ok
    }

    static func removeAll(_ trees: [Worktree], store: WorktreeStore, inUse: [String: String]) async {
        let bytes = trees.compactMap(\.sizeBytes).reduce(0, +)
        var removed = 0
        for tree in trees where await remove(tree, store: store, inUse: inUse) { removed += 1 }
        store.lastActionMessage = "Removed \(removed) of \(trees.count) worktrees, freeing about \(Format.bytes(bytes)). Branches are kept."
    }

    static func prune(repository: String, store: WorktreeStore) async {
        _ = await Task.detached { Git.runWithError(["worktree", "prune"], in: repository) }.value
        store.worktrees.filter { $0.repoRoot == repository && $0.isPrunable }.forEach { store.forget($0.path) }
        store.lastActionMessage = "Cleared missing worktrees from \((repository as NSString).lastPathComponent)"
    }

    static func reveal(_ tree: Worktree) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: tree.path)])
    }

    static func openInTerminal(_ tree: Worktree) {
        NSWorkspace.shared.open([URL(fileURLWithPath: tree.path)],
                                withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                configuration: NSWorkspace.OpenConfiguration())
    }

    static func confirmRemove(_ tree: Worktree) -> Bool {
        Confirm.quit(title: "Remove the worktree \(tree.name)?",
                     detail: "\(tree.verdict.reason). The folder is deleted and the branch \(tree.branch ?? "") is kept. Git refuses if anything is uncommitted.",
                     actionTitle: "Remove Worktree")
    }

    static func confirmRemoveAll(_ trees: [Worktree]) -> Bool {
        let bytes = trees.compactMap(\.sizeBytes).reduce(0, +)
        return Confirm.quit(title: "Remove \(trees.count) worktrees?",
                            detail: "Everything in them is already on main or their branch was deleted, they have no uncommitted changes, and nothing is using them. Frees about \(Format.bytes(bytes)). Branches are kept.",
                            actionTitle: "Remove \(trees.count) Worktrees")
    }
}
