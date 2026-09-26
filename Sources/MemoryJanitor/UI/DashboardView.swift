import SwiftUI

/// Which slice of processes the dashboard shows.
enum DashboardTab: String, CaseIterable, Identifiable {
    case suspects = "Likely leaks"
    case agents = "Agents"
    case user = "Your processes"
    case protected = "Protected"

    var id: String { rawValue }
    /// File-name form, e.g. "your-processes".
    var slug: String { rawValue.lowercased().replacingOccurrences(of: " ", with: "-") }
}

/// The full window: summary, bulk cleanup, and the process table.
struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var tab: DashboardTab

    init(initialTab: DashboardTab = .suspects) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let report = store.report {
                MemorySummaryView(system: report.system, reclaimableBytes: store.reclaimableBytes)
            } else {
                ProgressView("Reading memory…")
            }
            toolbar
            if tab == .agents {
                AgentsView(sessions: store.report?.agents ?? [],
                           duplicates: store.report?.duplicateToolServers ?? [])
            } else {
                ProcessTable(processes: rows, store: store)
            }
            if let message = store.lastActionMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 860, minHeight: 520)
        .tint(Palette.emerald500)
    }

    private var toolbar: some View {
        HStack {
            Picker("Show", selection: $tab) {
                ForEach(DashboardTab.allCases) { Text(label(for: $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Spacer()
            CleanupButton()
        }
    }

    private var rows: [ClassifiedProcess] {
        switch tab {
        case .suspects: return store.suspects
        case .agents: return []
        case .user: return store.userProcesses
        case .protected: return store.protectedProcesses
        }
    }

    private func label(for tab: DashboardTab) -> String {
        tab == .suspects ? "\(tab.rawValue) (\(store.suspects.count))" : tab.rawValue
    }
}
