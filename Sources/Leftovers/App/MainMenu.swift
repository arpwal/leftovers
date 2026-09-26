import AppKit

/// A minimal main menu. The app shows no menu bar of its own (it is a
/// menu-bar app), but these key equivalents still work inside its windows:
/// ⌘, Settings, ⌘W close, ⌘Q (see AppDelegate), and Edit → Copy for tables.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(title: "Leftovers", items: [
            ActionMenuItem(title: "Settings…", key: ",") { WindowCoordinator.shared.showSettings() },
            .separator(),
            NSMenuItem(title: "Quit Leftovers", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ]))
        main.addItem(submenu(title: "Edit", items: [
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
        ]))
        main.addItem(submenu(title: "Window", items: [
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
