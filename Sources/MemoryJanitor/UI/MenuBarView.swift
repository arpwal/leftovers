import SwiftUI

/// The popover under the menu-bar icon: summary + top leaks at a glance.
struct MenuBarView: View {
    @EnvironmentObject private var store: MonitorStore
    @Environment(\.openWindow) private var openWindow
    private static let previewCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let report = store.report {
                MemorySummaryView(system: report.system, reclaimableBytes: store.reclaimableBytes)
            } else {
                ProgressView("Reading memory…")
            }
            Divider()
            suspectList
            Divider()
            HStack {
                Button("Open dashboard") {
                    openWindow(id: MemoryJanitorApp.dashboardWindowID)
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                CleanupButton()
                Button("Quit app") { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 420)
        .tint(Palette.emerald500)
    }

    @ViewBuilder private var suspectList: some View {
        if store.suspects.isEmpty {
            Text("No leaks found. Nothing needs quitting.").foregroundStyle(.secondary)
        } else {
            ForEach(store.suspects.prefix(Self.previewCount)) { process in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(process.snapshot.name) · \(Format.bytes(process.snapshot.footprintBytes))")
                            .fontWeight(.medium)
                        Text(process.verdict.explanation).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ProcessActions(store: store, process: process)
                }
            }
        }
    }
}
