import SwiftUI

/// Git worktrees across your repositories. The last scan appears instantly;
/// a live strip shows what's being checked, and chips (which always add up)
/// filter the table.
struct WorktreesView: View {
    @ObservedObject var store: WorktreeStore
    @ObservedObject var monitor: MonitorStore
    @State private var selection = Set<Worktree.ID>()
    @State private var filter: WorktreeCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            activityStrip
            WorktreeChips(store: store, filter: $filter)
            if store.worktrees.isEmpty {
                if store.progress.isScanning || store.lastScan == nil { SkeletonRows() }
                else {
                    ContentUnavailableView("No Worktrees", systemImage: "arrow.triangle.branch",
                                           description: Text("Git worktrees in your code folders show up here."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                WorktreeTable(store: store, monitor: monitor, filter: filter, selection: $selection)
            }
        }
        .task {
            // Wait briefly for the first memory reading: it says which folders are in use.
            for _ in 0..<30 where monitor.report == nil { try? await Task.sleep(for: .milliseconds(100)) }
            await store.scan(inUse: monitor.workingFolders)
        }
    }

    private var activityStrip: some View {
        let p = store.progress
        return HStack(spacing: 8) {
            if p.isScanning {
                ActivityPill(text: p.isFinding ? "Finding repositories" : "\(p.repositories) repositories", isDone: !p.isFinding)
                if !p.isFinding {
                    ActivityPill(text: "Checked \(p.checked) of \(p.total)", isDone: p.checked == p.total)
                    ActivityPill(text: "Measured \(p.measured) of \(p.total)", isDone: p.measured == p.total)
                }
            }
            UpdatedAgo(date: store.lastScan, isWorking: p.isScanning)
            Spacer()
            Button("Rescan") { Task { await store.scan(inUse: monitor.workingFolders) } }
                .disabled(p.isScanning)
            Button(store.safe.isEmpty ? "Clean Up…" : "Clean Up \(store.safe.count)…") {
                let trees = store.safe
                guard WorktreeActions.confirmRemoveAll(trees) else { return }
                Task { await WorktreeActions.removeAll(trees, store: store, inUse: monitor.workingFolders) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.safe.isEmpty)
        }
    }
}

/// "All 78 · Safe 56 · Has changes 12 · …": counts that add up, and a filter.
struct WorktreeChips: View {
    @ObservedObject var store: WorktreeStore
    @Binding var filter: WorktreeCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("All", count: store.worktrees.count, selected: filter == nil) { filter = nil }
                ForEach(WorktreeCategory.allCases) { category in
                    let count = store.count(category)
                    if count > 0 || category == .safe {
                        chip(category.rawValue, count: count, selected: filter == category) {
                            filter = filter == category ? nil : category
                        }
                    }
                }
                if store.reclaimableBytes > 0 {
                    Text("\(Format.bytes(store.reclaimableBytes)) to free").font(.caption).foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
            }
        }
    }

    private func chip(_ title: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)").monospacedDigit().foregroundStyle(selected ? .primary : .secondary)
            }
            .font(.callout)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(selected ? Palette.emerald500.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Palette.emerald500.opacity(0.6) : .clear))
        }
        .buttonStyle(.plain)
    }
}
