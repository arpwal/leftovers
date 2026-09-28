import AppKit
import SwiftUI

/// `Leftovers --snapshot <dir> [--redact]`: renders the dashboard, welcome
/// pages and settings (light and dark) to PNGs offscreen, from live data,
/// in the same window styles the app uses. `--redact` makes them safe to publish.
@MainActor
enum SnapshotCommand {
    static let flag = "--snapshot"
    static let redactFlag = "--redact"
    /// Two refreshes, so CPU% (and idleness) are known before capture.
    private static let warmUp: TimeInterval = 7
    /// Rendered windows stay alive until exit: tearing one down while its
    /// Table cells still update detaches them from the environment and crashes.
    private static var windows: [NSWindow] = []
    private static let windowDelegate = SnapshotWindowDelegate()

    static func runAndExit(directory path: String, redact: Bool) {
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let store = MonitorStore()
        if redact {
            var redactor = ReportRedactor(privateTerms: ["amaltash"])
            store.reportTransform = { redactor.redact($0) }
        }
        RunLoop.main.run(until: Date().addingTimeInterval(warmUp))
        // Worktrees need a finished scan (~30 s on a busy machine), not a half-done one.
        let worktrees = WorktreeStore.shared
        let disk = DiskStore.shared
        Task { await worktrees.scan(inUse: store.workingFolders) }
        Task { await disk.scan() }
        let advanced = AdvancedStore.shared
        for tool in AdvancedTool.allCases { Task { await advanced.scan(tool, monitor: store) } }
        let deadline = Date().addingTimeInterval(240)
        repeat { RunLoop.main.run(until: Date().addingTimeInterval(0.5)) }
            while (worktrees.progress.isScanning || disk.progress.isScanning || disk.lastScan == nil
                   || AdvancedTool.allCases.contains(where: advanced.isBusy)) && Date() < deadline
        if redact {
            worktrees.showForSnapshot(WorktreeRedactor.redact(worktrees.worktrees))
            advanced.hideForSnapshot(containing: ["amaltash"])
        }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            renderAll(store: store, appearance: appearance, suffix: name, into: directory)
        }
        exit(0)
    }

    private static func renderAll(store: MonitorStore, appearance: NSAppearance.Name, suffix: String, into directory: URL) {
        for section in DashboardSection.allCases {
            store.dashboardSection = section
            let window = WindowFactory.dashboard(snapshotRoot(DashboardView(), store), delegate: windowDelegate)
            capture(window, appearance: appearance, settle: 0.8, to: directory.appendingPathComponent("dashboard-\(section.slug)-\(suffix).png"))
        }
        for page in OnboardingPage.allCases {
            let window = WindowFactory.welcome(snapshotRoot(OnboardingView(initialPage: page), store), delegate: windowDelegate)
            capture(window, appearance: appearance, settle: 5, to: directory.appendingPathComponent("welcome-\(page.rawValue + 1)-\(suffix).png"))
        }
        let header = WindowFactory.settings(snapshotRoot(MenuHeaderView(store: store), store), delegate: windowDelegate)
        capture(header, appearance: appearance, settle: 0.5, to: directory.appendingPathComponent("menu-header-\(suffix).png"))
        let settings = WindowFactory.settings(snapshotRoot(SettingsView(store: store), store), delegate: windowDelegate)
        capture(settings, appearance: appearance, settle: 0.8, to: directory.appendingPathComponent("settings-\(suffix).png"))
    }

    /// Offscreen capture skips the window's own background; paint it.
    private static func snapshotRoot<V: View>(_ view: V, _ store: MonitorStore) -> some View {
        view.environmentObject(store)
            .environment(\.isSnapshot, true)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    private static func capture(_ window: NSWindow, appearance: NSAppearance.Name, settle: TimeInterval, to url: URL) {
        window.appearance = NSAppearance(named: appearance)
        windows.append(window)
        guard let view = window.contentView else { return }
        // Let Table, async layout and entrance animations settle before capturing.
        RunLoop.main.run(until: Date().addingTimeInterval(settle))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// Snapshot windows need a delegate; they are never closed.
private final class SnapshotWindowDelegate: NSObject, NSWindowDelegate {}
