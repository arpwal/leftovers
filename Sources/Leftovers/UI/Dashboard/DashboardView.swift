import SwiftUI

/// The dashboard window: sidebar navigation under the traffic lights,
/// no title bar and no tab bar.
struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot { snapshotLayout } else { splitView }
    }

    /// Offscreen capture can't draw the split view's translucent sidebar, so
    /// snapshots lay the same two columns out side by side.
    private var snapshotLayout: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $store.dashboardSection)
                .frame(width: 220)
                .padding(.top, 28) // where the traffic lights sit
                .background(Color.snapshotSidebar)
            Divider()
            SectionPane(section: store.dashboardSection)
                .frame(minWidth: 0, maxWidth: .infinity)
        }
        .tint(Palette.emerald500)
    }

    private var splitView: some View {
        NavigationSplitView {
            SidebarView(selection: $store.dashboardSection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            SectionPane(section: store.dashboardSection)
        }
        .toolbar(removing: .sidebarToggle)
        .tint(Palette.emerald500)
        .frame(minWidth: 900, minHeight: 560)
    }
}
