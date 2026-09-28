import SwiftUI

/// The detail column: header, headline numbers, then the section's content.
struct SectionPane: View {
    @EnvironmentObject private var store: MonitorStore
    let section: DashboardSection
    @ObservedObject private var scheduled = ScheduledStore.shared
    @ObservedObject private var worktrees = WorktreeStore.shared
    @ObservedObject private var disk = DiskStore.shared
    @ObservedObject private var advanced = AdvancedStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(section: section)
            if let system = store.system, section != .overview, section != .disk, section.advancedTool == nil {
                StatCards(system: system, reclaimableBytes: store.report.map { _ in store.reclaimableBytes })
            }
            if let tool = section.advancedTool {
                AdvancedView(tool: tool, store: advanced, monitor: store)
                if let message = advanced.lastActionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            } else if section == .disk {
                DiskView(store: disk, monitor: store, worktrees: worktrees)
                if let message = disk.lastActionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            } else if section == .worktrees {
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
        case .overview:
            OverviewView(store: store, worktrees: worktrees, jobs: scheduled, caches: disk)
                .task { await worktrees.scanIfStale(monitor: store); await scheduled.reload() }
                .task { await disk.scanIfStale() }
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
        case .scheduled, .worktrees, .disk, .aiModels, .docker, .nodeModules, .simulators, .snapshots: EmptyView()   // rendered above; need no memory reading
        case .processes: ProcessTable(processes: store.userProcesses, store: store)
        case .protected: ProcessTable(processes: store.protectedProcesses, store: store)
        }
    }
}
