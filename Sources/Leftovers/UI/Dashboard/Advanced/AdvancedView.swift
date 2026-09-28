import SwiftUI

/// One Advanced section: a live strip, an optional notice, and a sortable,
/// multi-select table with Remove for one row or the whole selection.
struct AdvancedView: View {
    let tool: AdvancedTool
    @ObservedObject var store: AdvancedStore
    @ObservedObject var monitor: MonitorStore
    @State private var selection = Set<CleanableItem.ID>()

    private var report: ToolReport? { store.reports[tool] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            strip
            if let notice = report?.notice { Text(notice).foregroundStyle(.secondary) }
            if let report, !report.items.isEmpty {
                AdvancedTable(items: report.items, selection: $selection) { remove($0) }
            } else if report == nil {
                SkeletonRows()
            }
        }
        .task(id: tool) { selection = []; await store.scanIfStale(tool, monitor: monitor) }
    }

    private var strip: some View {
        HStack(spacing: 8) {
            if store.scanning.contains(tool) { ActivityPill(text: "Looking", isDone: false) }
            if let m = store.measuring[tool] { ActivityPill(text: "Measured \(m.done) of \(m.total)", isDone: m.done == m.total) }
            UpdatedAgo(date: report?.scannedAt, isWorking: store.isBusy(tool))
            Spacer()
            Button("Select All Removable") { selection = Set((report?.items ?? []).filter(\.canRemove).map(\.id)) }
                .disabled(!(report?.items.contains(where: \.canRemove) ?? false))
            Button("Rescan") { Task { await store.scan(tool, monitor: monitor) } }.disabled(store.isBusy(tool))
            Button(selectedRemovable.isEmpty ? "Remove…" : "Remove \(selectedRemovable.count) · \(Format.bytes(selectedBytes))…") {
                remove(selectedRemovable)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedRemovable.isEmpty)
        }
    }

    private var selectedRemovable: [CleanableItem] {
        (report?.items ?? []).filter { selection.contains($0.id) && $0.canRemove }
    }
    private var selectedBytes: UInt64 { selectedRemovable.compactMap(\.bytes).reduce(0, +) }

    private func remove(_ items: [CleanableItem]) {
        Task {
            await AdvancedActions.remove(items, tool: tool, store: store, monitor: monitor)
            selection.subtract(items.map(\.id))
        }
    }
}
