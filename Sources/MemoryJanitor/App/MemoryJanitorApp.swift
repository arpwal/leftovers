import SwiftUI

/// Menu-bar app: the icon shows swap usage; the popover and dashboard
/// show what is leaking and let you reclaim it.
@main
struct MemoryJanitorApp: App {
    static let dashboardWindowID = "dashboard"
    @StateObject private var store = MonitorStore()

    init() {
        CommandLineInterface.runIfRequested()
        SnapshotCommand.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView().environmentObject(store)
        } label: {
            Label { Text(menuTitle) } icon: { Image(nsImage: MenuBarGlyph.image) }
                .labelStyle(.titleAndIcon)
        }
        .menuBarExtraStyle(.window)

        Window("Memory Janitor", id: Self.dashboardWindowID) {
            DashboardView().environmentObject(store)
        }
    }

    /// Show the reclaimable amount only when there is something to reclaim.
    private var menuTitle: String {
        store.suspects.isEmpty ? "" : Format.bytes(store.reclaimableBytes)
    }
}
