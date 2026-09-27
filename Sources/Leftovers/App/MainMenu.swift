import AppKit

/// The main menu, shown while Leftovers is active (it is a Dock app by
/// default). Its key equivalents also work when the Dock icon is hidden:
/// ⌘, Settings, ⌘W close, ⌘Q (see QuitController), and Edit → Copy for tables.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(title: "Leftovers", items: [
            NSMenuItem(title: "About Leftovers", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""),
            ActionMenuItem(title: "Check for Updates…") { UpdateController.shared.checkForUpdates() },
            ActionMenuItem(title: "What's New in Leftovers…") { NSWorkspace.shared.open(AppLinks.changelog) },
            .separator(),
            ActionMenuItem(title: "Settings…", key: ",") { WindowCoordinator.shared.showSettings() },
            .separator(),
            NSMenuItem(title: "Hide Leftovers", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"),
            NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""),
            .separator(),
            ActionMenuItem(title: "Quit Leftovers", key: "q") { QuitController.commandQ() },
        ]))
        main.addItem(submenu(title: "Edit", items: [
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
        ]))
        main.addItem(submenu(title: "Window", items: [
            ActionMenuItem(title: "Leftovers Dashboard", key: "0") { WindowCoordinator.shared.showDashboard() },
            NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"),
            NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"),
        ]))
        return main
    }

    private static func submenu(title: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        item.submenu = menu
        return item
    }
}
