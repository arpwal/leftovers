import AppKit

/// The menu's fseventsd block, shown only while it's over its limits (or
/// being restarted): what it's using, Restart, and how to allow automatic
/// restarts when the helper isn't approved yet. Its own block, apart from
/// Likely Leaks, so "Clean Up All" never includes it.
@MainActor
struct FseventsdMenuItems {
    let watchdog: FseventsdWatchdog
    private var windows: WindowCoordinator { .shared }

    func items() -> [NSMenuItem] {
        guard let health = watchdog.health, health.needsRestart || watchdog.isRestarting else { return [] }
        var items: [NSMenuItem] = [.separator(), .sectionHeader(title: "fseventsd Is Running Away")]
        let warning = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
        let row = ActionMenuItem(title: "fseventsd — \(health.usage)", image: warning) { windows.showDashboard(section: .leaks) }
        row.toolTip = "macOS's file-event service: \(health.reason)"
        items.append(row)
        items.append(restartItem())
        if watchdog.helperStatus.canRegister {
            items.append(ActionMenuItem(title: "Allow Automatic Restarts…") { watchdog.enableHelper() })
        }
        if let last = watchdog.lastRestart { items.append(disabled(last.summary)) }
        return items
    }

    private func restartItem() -> NSMenuItem {
        guard !watchdog.isRestarting else { return disabled("Restarting fseventsd…") }
        // Without the helper macOS asks for an administrator password: hence the ellipsis.
        let title = watchdog.helperStatus.isReady ? "Restart fseventsd" : "Restart fseventsd…"
        return ActionMenuItem(title: title) { Task { await watchdog.restart(trigger: .manual) } }
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
