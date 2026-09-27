import Foundation

/// Runs every worktree through "check" (git status + squash check) and
/// "measure" (du) off the main thread, with checks and measurements in
/// flight at the same time, delivering each result as soon as it lands.
enum WorktreePipeline {
    enum Event: Sendable {
        case checked(Worktree)
        case measured(path: String, size: UInt64?)
    }

    /// A freshly listed worktree, showing the last scan's verdict and size
    /// (marked stale) until it is re-checked.
    static func carryOver(from old: Worktree?, into fresh: Worktree) -> Worktree {
        var tree = fresh
        if let old, old.verdict != .checking {
            tree.verdict = old.verdict
            tree.sizeBytes = old.sizeBytes
            tree.isStale = true
        }
        return tree
    }

    static func run(_ trees: [Worktree], inUse: [String: String], inFlight: Int, sizesInFlight: Int,
                    deliver: @MainActor (Event) -> Void) async {
        await withTaskGroup(of: Event.self) { group in
            var checks = trees.reversed() as [Worktree]
            var sizes: [String] = []
            var running = 0, measuring = 0
            while true {
                while running < inFlight {
                    if !sizes.isEmpty, measuring < sizesInFlight || checks.isEmpty {
                        let path = sizes.removeLast()
                        group.addTask { .measured(path: path, size: Git.size(of: path)) }
                        measuring += 1
                    } else if let tree = checks.popLast() {
                        group.addTask { .checked(check(tree, inUse: inUse)) }
                    } else { break }
                    running += 1
                }
                guard running > 0, let event = await group.next() else { break }
                running -= 1
                if case let .checked(tree) = event {
                    // Removable ones are measured first: their size is what cleanup frees.
                    if tree.verdict.canRemove { sizes.append(tree.path) } else { sizes.insert(tree.path, at: 0) }
                } else { measuring -= 1 }
                await deliver(event)
            }
        }
    }

    static func check(_ tree: Worktree, inUse: [String: String]) -> Worktree {
        var checked = tree.isPrunable ? tree : WorktreeScanner.check(tree)
        checked.inUseBy = WorktreeStore.user(of: tree.path, in: inUse)
        checked.verdict = WorktreeJudge.verdict(for: checked)
        checked.isStale = false
        return checked
    }
}
