import SwiftUI

/// The detail column: header, headline numbers, then the section's content.
struct SectionPane: View {
    @EnvironmentObject private var store: MonitorStore
    let section: DashboardSection
    @ObservedObject private var scheduled = ScheduledStore.shared
    @ObservedObject private var worktrees = WorktreeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(section: section)
            if let system = store.system {
                StatCards(system: system, reclaimableBytes: store.report.map { _ in store.reclaimableBytes })
            }
            if section == .worktrees {
                WorktreesView(store: worktrees, monitor: store)
                if let message = worktrees.lastActionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            } else if section == .scheduled {
                ScheduledTable(store: scheduled)
                if let message = scheduled.lastActionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            } else if let report = store.report {
                content(report)
            } else {
                SkeletonRows()
            }
            if let message = store.lastActionMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func content(_ report: MemoryReport) -> some View {
        switch section {
        case .leaks:
            if store.suspects.isEmpty {
                ContentUnavailableView("No Leaks Found", systemImage: "checkmark.seal",
                                       description: Text("Nothing is holding memory it doesn't use."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProcessTable(processes: store.suspects, store: store)
            }
        case .apps: AppsTable(groups: store.appGroups, totalBytes: report.system.totalBytes, store: store)
        case .agents:
            if report.agentsReady {
                AgentsTable(sessions: report.agents, duplicates: report.duplicateToolServers, store: store)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ActivityPill(text: "Reading agent sessions", isDone: false)
                    SkeletonRows(count: 5)
                }
            }
        case .scheduled, .worktrees: EmptyView()   // rendered above; need no memory reading
        case .processes: ProcessTable(processes: store.userProcesses, store: store)
        case .protected: ProcessTable(processes: store.protectedProcesses, store: store)
        }
    }
}
