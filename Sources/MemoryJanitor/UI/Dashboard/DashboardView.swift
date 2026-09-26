import SwiftUI

/// The dashboard window: sidebar navigation under the traffic lights,
/// no title bar and no tab bar.
struct DashboardView: View {
    @EnvironmentObject private var store: MonitorStore

    var body: some View {
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
