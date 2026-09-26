import AppKit

/// The standard part of the menu: leaks, top apps, agents, then app commands.
/// Plain NSMenuItems with each app's real logo — no custom colours.
@MainActor
struct StatusMenuBuilder {
    let store: MonitorStore
    private static let leakLimit = 8
    private static let appLimit = 5
    private var windows: WindowCoordinator { .shared }

    func items() -> [NSMenuItem] {
        [.separator()] + leakItems() + [.separator()] + appItems() + agentItems()
            + [.separator()] + commandItems()
    }

    private func leakItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = [.sectionHeader(title: "Likely Leaks")]
        if store.suspects.isEmpty {
            items.append(disabled("Nothing left behind"))
        }
        for process in store.suspects.prefix(Self.leakLimit) {
            let title = "\(process.snapshot.name) — \(Format.bytes(process.snapshot.footprintBytes))"
            items.append(ActionMenuItem(title: title, image: menuIcon(AppIconProvider.icon(for: process.snapshot))) {
                ProcessCommands.quit(process, store: store)
            })
        }
        let cleanTitle = store.suspects.isEmpty ? "Clean Up All…" : "Clean Up All (\(Format.bytes(store.reclaimableBytes)))…"
        let clean = ActionMenuItem(title: cleanTitle) { ProcessCommands.cleanUpAll(store: store) }
        clean.isEnabled = !store.suspects.isEmpty
        items.append(clean)
        return items
    }

    /// Each app opens a submenu: quit it (when safe) or see it in the dashboard.
    private func appItems() -> [NSMenuItem] {
        [.sectionHeader(title: "Using the Most Memory")] + store.appGroups.prefix(Self.appLimit).map { group in
            let item = NSMenuItem(title: "\(group.name) — \(Format.bytes(group.totalFootprint))", action: nil, keyEquivalent: "")
            item.image = menuIcon(AppIconProvider.icon(atPath: group.bundlePath))
            let submenu = NSMenu()
            if AppQuitter.canQuit(group, protectedNames: store.protectedNames) {
                submenu.addItem(ActionMenuItem(title: "Quit \(group.name)…") {
                    guard Confirm.quitApp(group) else { return }
                    Task { await store.quitApp(group) }
                })
            }
            submenu.addItem(ActionMenuItem(title: "Show in Leftovers") { windows.showDashboard(section: .apps) })
            item.submenu = submenu
            return item
        }
    }

    /// One line per agent kind, e.g. "Claude Code ×12 — 14.2 GB".
    private func agentItems() -> [NSMenuItem] {
        let sessions = store.report?.agents ?? []
        guard !sessions.isEmpty else { return [] }
        let byKind = Dictionary(grouping: sessions, by: \.kind).sorted { $0.key.rawValue < $1.key.rawValue }
        return [.sectionHeader(title: "Agents")] + byKind.map { kind, group in
            let bytes = group.reduce(UInt64(0)) { $0 + $1.totalFootprint }
            let icon = AppIconProvider.icon(for: kind).map { menuIcon($0) }
            return ActionMenuItem(title: "\(kind.rawValue) ×\(group.count) — \(Format.bytes(bytes))", image: icon) {
                windows.showDashboard(section: .agents)
            }
        }
    }

    private func commandItems() -> [NSMenuItem] {
        [
            ActionMenuItem(title: "Open Leftovers", key: "d") { windows.showDashboard() },
            ActionMenuItem(title: "Check for Updates…") { UpdateController.shared.checkForUpdates() },
            ActionMenuItem(title: "Settings…", key: ",") { windows.showSettings() },
            .separator(),
            ActionMenuItem(title: "Quit Leftovers", key: "q") { QuitController.quitCompletely() },
        ]
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func menuIcon(_ image: NSImage) -> NSImage { AppIconProvider.menuSized(image) }
}
