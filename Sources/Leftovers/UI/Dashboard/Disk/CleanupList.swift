import SwiftUI

/// What can be cleaned without losing work: developer caches that rebuild
/// themselves, and finished worktrees (handled in their own section).
struct CleanupList: View {
    @ObservedObject var store: DiskStore
    @ObservedObject var monitor: MonitorStore
    @ObservedObject var worktrees: WorktreeStore

    var body: some View {
        let running = DiskActions.runningNames(monitor)
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                header(ready: DiskActions.split(store.cleanableCaches, running: running).ready)
                if store.caches.isEmpty && store.progress.isScanning { SkeletonRows(count: 4) }
                ForEach(store.cleanableCaches) { item in
                    CleanupRow(item: item, blocker: item.target.blocker(running: running)) {
                        Task { await DiskActions.empty([item], store: store, monitor: monitor) }
                    }
                }
                if !store.progress.isScanning && store.cleanableCaches.isEmpty {
                    Text("No developer caches worth clearing.").foregroundStyle(.secondary).padding(.vertical, 6)
                }
                Divider().padding(.vertical, 6)
                worktreesRow
            }
            .padding(16)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func header(ready: [DiskStore.CacheItem]) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Developer caches").font(.headline)
                Text("They rebuild themselves. Your code and documents are never touched.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(ready.isEmpty ? "Empty All…" : "Empty All \(Format.bytes(ready.compactMap(\.bytes).reduce(0, +)))…") {
                Task { await DiskActions.empty(ready, store: store, monitor: monitor) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(ready.isEmpty || store.progress.isScanning)
        }
        .padding(.bottom, 8)
    }

    private var worktreesRow: some View {
        Button { monitor.dashboardSection = .worktrees } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch").frame(width: 20).foregroundStyle(Palette.emerald600)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Worktrees already on main")
                    Text("\(worktrees.safe.count) safe to remove").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Format.bytes(worktrees.safe.compactMap(\.sizeBytes).reduce(0, +))).monospacedDigit().foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One cache: what it is, what emptying costs, its size and the button.
struct CleanupRow: View {
    let item: DiskStore.CacheItem
    let blocker: String?
    let empty: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox").frame(width: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.target.title)
                Text(blocker.map { "In use by \($0)" } ?? item.target.cost)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(item.bytes.map(Format.bytes) ?? "…").monospacedDigit().foregroundStyle(.secondary)
            Button("Empty", action: empty).controlSize(.small).disabled(blocker != nil)
        }
        .padding(.vertical, 5)
        .contextMenu { Button("Show in Finder") { DiskActions.reveal(item.target.path()) } }
    }
}
