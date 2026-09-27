import SwiftUI

/// Sidebar: app identity, destinations with live counts, pressure at the bottom.
struct SidebarView: View {
    @EnvironmentObject private var store: MonitorStore
    @Binding var selection: DashboardSection
    @ObservedObject private var scheduled = ScheduledStore.shared
    @ObservedObject private var worktrees = WorktreeStore.shared
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(DashboardSection.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .badge(count(for: section))
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(isSnapshot ? .hidden : .automatic)
        .background(isSnapshot ? Color.snapshotSidebar : .clear)
        .safeAreaInset(edge: .bottom) { pressureFooter }
    }

    private func count(for section: DashboardSection) -> Int {
        switch section {
        case .leaks: return store.suspects.count
        case .apps: return store.appGroups.count
        case .agents: return store.report?.agents.count ?? 0
        case .worktrees: return worktrees.safe.count
        case .scheduled: return scheduled.jobs.count
        case .processes: return store.userProcesses.count
        case .protected: return 0
        }
    }

    private var pressureFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let system = store.system {
                HStack(spacing: 8) {
                    Circle().fill(Palette.color(for: system.pressure)).frame(width: 8, height: 8)
                    Text("Pressure \(system.pressure.label.lowercased())")
                    Spacer()
                    Text("\(system.availablePercent)% free").monospacedDigit()
                }
            }
            ScanSpeedLabel(stats: store.scanStats)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
