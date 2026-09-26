import AppKit
import SwiftUI

/// Creates, shows and releases the app's three windows. Each window's content
/// is torn down when it closes, so a hidden dashboard costs no CPU or memory.
@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = WindowCoordinator()
    var store: MonitorStore?

    private var dashboard: NSWindow?
    private var welcome: NSWindow?
    private var settings: NSWindow?

    func showDashboard(section: DashboardSection? = nil) {
        guard let store else { return }
        if let section { store.dashboardSection = section }
        dashboard = dashboard ?? WindowFactory.dashboard(DashboardView().environmentObject(store), delegate: self)
        present(dashboard)
    }

    func showWelcome() {
        welcome = welcome ?? WindowFactory.welcome(OnboardingView(), delegate: self)
        present(welcome)
    }

    func showSettings() {
        guard let store else { return }
        settings = settings ?? WindowFactory.settings(SettingsView(store: store), delegate: self)
        present(settings)
    }

    /// Called by the welcome flow's last step.
    func finishWelcome() {
        UserDefaults.standard.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        welcome?.close()
        showDashboard()
    }

    func closeAll() {
        [dashboard, welcome, settings].forEach { $0?.close() }
    }

    private func present(_ window: NSWindow?) {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        window.contentViewController = nil
        if window === dashboard { dashboard = nil }
        if window === welcome { welcome = nil }
        if window === settings { settings = nil }
    }
}
