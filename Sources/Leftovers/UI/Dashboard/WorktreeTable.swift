import SwiftUI

struct WorktreeTable: View {
    @ObservedObject var store: WorktreeStore
    let monitor: MonitorStore
    @Binding var selection: Set<Worktree.ID>

    var body: some View {
        Table(store.worktrees, selection: $selection) {
            TableColumn("Worktree") { tree in
                VStack(alignment: .leading, spacing: 1) {
                    Text(tree.name).fontWeight(.medium).lineLimit(1)
                    Text("\(tree.repoName) · \(tree.branch ?? "detached")").font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).help(tree.path)
                }
            }
            .width(min: 160, ideal: 280)
            TableColumn("Status") { WorktreeBadge(verdict: $0.verdict) }.width(min: 120, ideal: 200)
            TableColumn("Last commit") { tree in
                Text(tree.lastCommit.map { $0.formatted(.relative(presentation: .named)) } ?? "—").lineLimit(1)
            }
            .width(min: 70, ideal: 100)
            TableColumn("Size") { tree in
                Text(tree.sizeBytes.map(Format.bytes) ?? (tree.isMain ? "—" : "…")).monospacedDigit()
            }
            .width(min: 60, ideal: 80)
            TableColumn("") { tree in
                if tree.verdict.canRemove { Button("Remove") { remove(tree) }.controlSize(.small) }
            }
            .width(min: 64, ideal: 72)
        }
        .contextMenu(forSelectionType: Worktree.ID.self) { ids in
            let trees = store.worktrees.filter { ids.contains($0.id) }
            if let tree = trees.first {
                Button("Show in Finder") { WorktreeActions.reveal(tree) }
                Button("Open in Terminal") { WorktreeActions.openInTerminal(tree) }
                Divider()
                if tree.verdict == .missing {
                    Button("Clear Missing Worktrees") { Task { await WorktreeActions.prune(repository: tree.repoRoot, store: store) } }
                }
                if tree.verdict.canRemove { Button("Remove Worktree…") { remove(tree) } }
            }
        } primaryAction: { ids in
            store.worktrees.filter { ids.contains($0.id) }.forEach(WorktreeActions.reveal)
        }
    }

    private func remove(_ tree: Worktree) {
        guard WorktreeActions.confirmRemove(tree) else { return }
        Task { _ = await WorktreeActions.remove(tree, store: store, inUse: monitor.workingFolders) }
    }
}

/// Green for safe, amber for probably done, grey for keep.
struct WorktreeBadge: View {
    let verdict: WorktreeVerdict

    var body: some View {
        HStack(spacing: 6) {
            if verdict == .checking { ProgressView().controlSize(.mini) } else { Circle().fill(color).frame(width: 7, height: 7) }
            Text(verdict.reason).lineLimit(1).help(verdict.reason)
        }
    }

    private var color: Color {
        switch verdict {
        case .safe: return Palette.emerald500
        case .probablyDone, .missing: return Palette.amber500
        case .keep, .checking: return .secondary
        }
    }
}
