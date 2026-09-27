import SwiftUI

/// Git worktrees across your repositories: which are safe to remove, which
/// are probably done, and which to keep. One at a time or in bulk.
struct WorktreesView: View {
    @ObservedObject var store: WorktreeStore
    @ObservedObject var monitor: MonitorStore
    @State private var selection = Set<Worktree.ID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryBar
            if store.worktrees.isEmpty {
                if store.phase == .done {
                    ContentUnavailableView("No Worktrees", systemImage: "arrow.triangle.branch",
                                           description: Text("Git worktrees in your code folders show up here."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LoadingState(text: "Finding repositories…")
                }
            } else {
                WorktreeTable(store: store, monitor: monitor, selection: $selection)
            }
        }
        .task {
            guard store.phase == .idle else { return }
            // Wait for the first memory reading: it says which folders are in use.
            for _ in 0..<50 where monitor.report == nil { try? await Task.sleep(for: .milliseconds(100)) }
            await store.scan(inUse: monitor.workingFolders)
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 12) {
            Text(summary).foregroundStyle(.secondary).monospacedDigit()
            if case let .checking(done, total) = store.phase { progress(done, total, "Checking") }
            if case let .measuring(done, total) = store.phase { progress(done, total, "Measuring") }
            Spacer()
            Button("Rescan") { Task { await store.scan(inUse: monitor.workingFolders) } }
                .disabled(store.phase != .done)
            Button(store.safe.isEmpty ? "Clean Up…" : "Clean Up \(store.safe.count)…") {
                let trees = store.safe
                guard WorktreeActions.confirmRemoveAll(trees) else { return }
                Task { await WorktreeActions.removeAll(trees, store: store, inUse: monitor.workingFolders) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.safe.isEmpty)
        }
    }

    private var summary: String {
        let count = store.worktrees.filter { !$0.isMain }.count
        let removable = store.worktrees.filter(\.verdict.canRemove).count
        var parts = ["\(count) worktrees", "\(store.safe.count) safe to remove", "\(removable - store.safe.count) probably done"]
        if store.reclaimableBytes > 0 { parts.append("\(Format.bytes(store.reclaimableBytes)) to free") }
        return parts.joined(separator: " · ")
    }

    private func progress(_ done: Int, _ total: Int, _ verb: String) -> some View {
        HStack(spacing: 6) {
            ProgressView(value: Double(done), total: Double(max(total, 1))).frame(width: 80)
            Text("\(verb) \(done) of \(total)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
