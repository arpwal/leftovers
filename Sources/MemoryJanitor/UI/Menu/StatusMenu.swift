import SwiftUI

/// The menu-bar menu: a standard macOS menu with no custom colours.
/// Status lines are disabled items, apps and leaks carry their real logos.
struct StatusMenu: View {
    @ObservedObject var store: MonitorStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    private static let leakLimit = 8
    private static let appLimit = 5

    var body: some View {
        status
        Divider()
        Section("Likely Leaks") {
            if store.suspects.isEmpty {
                Text("No leaks found")
            } else {
                ForEach(store.suspects.prefix(Self.leakLimit)) { process in
                    Button { ProcessCommands.quit(process, store: store) } label: {
                        iconLabel("\(process.snapshot.name) — \(Format.bytes(process.snapshot.footprintBytes))",
                                  AppIconProvider.icon(for: process.snapshot))
                    }
                }
            }
            Button("Clean Up All Leaks (\(Format.bytes(store.reclaimableBytes)))…") { cleanUp() }
                .disabled(store.suspects.isEmpty)
        }
        Divider()
        Section("Using the Most Memory") {
            ForEach(store.appGroups.prefix(Self.appLimit)) { group in
                Button { openDashboard(at: .apps) } label: {
                    iconLabel("\(group.name) — \(Format.bytes(group.totalFootprint))",
                              AppIconProvider.icon(atPath: group.bundlePath))
                }
            }
        }
        Divider()
        Button("Open Dashboard") { openDashboard(at: store.dashboardSection) }
            .keyboardShortcut("d")
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Memory Janitor") { QuitController.quitCompletely() }
            .keyboardShortcut("q")
    }

    @ViewBuilder private var status: some View {
        if let system = store.report?.system {
            Text("Memory Pressure: \(system.pressure.label)")
            Text("Swap: \(Format.bytes(system.swapUsedBytes)) of \(Format.bytes(system.swapTotalBytes))")
            Text("Reclaimable: \(Format.bytes(store.reclaimableBytes))")
        } else {
            Text("Reading memory…")
        }
    }

    private func iconLabel(_ title: String, _ icon: NSImage) -> some View {
        Label { Text(title) } icon: { Image(nsImage: AppIconProvider.menuSized(icon)) }
    }

    private func openDashboard(at section: DashboardSection) {
        store.dashboardSection = section
        openWindow(id: MemoryJanitorApp.dashboardWindowID)
        NSApp.activate()
    }

    private func cleanUp() {
        guard Confirm.cleanUp(store.suspects, freeing: store.reclaimableBytes) else { return }
        Task { await store.terminateAllSuspects() }
    }
}
