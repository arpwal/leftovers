import SwiftUI

/// Where your disk goes (system, apps, yours) and what can safely be
/// cleaned. Volume numbers appear at once; sizes fill in as they're measured.
struct DiskView: View {
    enum Tab: String, CaseIterable { case cleanup = "Clean Up", apps = "Apps" }

    @ObservedObject var store: DiskStore
    @ObservedObject var monitor: MonitorStore
    @ObservedObject var worktrees: WorktreeStore
    @State private var tab = Tab.cleanup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            activityStrip
            if let breakdown = store.breakdown { DiskBreakdownCard(breakdown: breakdown, isMeasuring: store.isFirstScan) }
            Picker("", selection: $tab) { ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) } }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            switch tab {
            case .cleanup: CleanupList(store: store, monitor: monitor, worktrees: worktrees)
            case .apps: DiskAppsTable(store: store)
            }
        }
        .task { await store.scanIfStale() }
    }

    private var activityStrip: some View {
        let p = store.progress
        return HStack(spacing: 8) {
            if p.isScanning {
                ActivityPill(text: p.total == 0 ? "Reading volumes and apps" : "\(store.lastScan == nil ? "Measured" : "Refreshed") \(p.measured) of \(p.total)",
                             isDone: p.total > 0 && p.measured == p.total)
            }
            UpdatedAgo(date: store.lastScan, isWorking: p.isScanning)
            Spacer()
            Button("Rescan") { Task { await store.scan() } }.disabled(p.isScanning)
        }
    }
}
