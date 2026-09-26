import AppKit
import SwiftUI

/// `MemoryJanitor --snapshot <dir>`: renders the popover and dashboard (light
/// and dark) to PNGs offscreen, from live data. Used for README screenshots.
@MainActor
enum SnapshotCommand {
    static let flag = "--snapshot"
    /// Two refreshes, so CPU% (and idleness) are known before capture.
    private static let warmUp: TimeInterval = 7
    /// Rendered windows stay alive until exit: tearing one down while its
    /// Table cells still update detaches them from the environment and crashes.
    private static var windows: [NSWindow] = []

    static func runIfRequested() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return }
        let directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let store = MonitorStore()
        RunLoop.main.run(until: Date().addingTimeInterval(warmUp))
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for section in DashboardSection.allCases {
                store.dashboardSection = section
                render(DashboardView(), size: NSSize(width: 1100, height: 700), store: store,
                       appearance: appearance, to: directory.appendingPathComponent("dashboard-\(section.slug)-\(name).png"))
            }
            render(SettingsView(store: store), size: NSSize(width: 500, height: 560), store: store,
                   appearance: appearance, to: directory.appendingPathComponent("settings-\(name).png"))
        }
        exit(0)
    }

    private static func render<V: View>(_ view: V, size: NSSize, store: MonitorStore,
                                        appearance: NSAppearance.Name, to url: URL) {
        // Offscreen capture skips the window's own background; paint it.
        let root = view.environmentObject(store).background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        windows.append(window)
        // Let Table and async layout settle before capturing.
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}
