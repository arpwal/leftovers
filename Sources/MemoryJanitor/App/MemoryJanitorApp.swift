import SwiftUI

/// Menu-bar app. The menu shows status and leaks; the dashboard window has the
/// full picture; ⌘Q closes the window and keeps the menu-bar item running
/// unless Settings say otherwise.
@main
struct MemoryJanitorApp: App {
    static let dashboardWindowID = "dashboard"
    static let onboardingWindowID = "welcome"
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MonitorStore()
    @AppStorage(SettingsKey.showReclaimableInMenuBar) private var showReclaimable = true

    init() {
        CommandLineInterface.runIfRequested()
        SnapshotCommand.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenu(store: store)
        } label: {
            MenuBarLabel(title: menuTitle)
        }
        .menuBarExtraStyle(.menu)

        Window("Memory Janitor", id: Self.dashboardWindowID) {
            DashboardView().environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentMinSize)

        Window("Welcome to Memory Janitor", id: Self.onboardingWindowID) {
            OnboardingView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView(store: store)
        }
    }

    /// Show the reclaimable amount only when there is something to reclaim.
    private var menuTitle: String {
        guard showReclaimable, !store.suspects.isEmpty else { return "" }
        return Format.bytes(store.reclaimableBytes)
    }
}
