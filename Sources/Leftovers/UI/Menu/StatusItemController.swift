import AppKit
import Combine
import SwiftUI

/// The menu-bar item: a live dial glyph, the reclaimable amount when there
/// is something to reclaim, and a standard NSMenu rebuilt each time it opens.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: MonitorStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private lazy var header = makeHeaderItem()
    private var subscription: AnyCancellable?

    init(store: MonitorStore) {
        self.store = store
        super.init()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageLeading
        subscription = store.objectWillChange
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateButton() }
        updateButton()
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let available = Double(store.system?.availablePercent ?? 100)
        button.image = MenuBarGlyph.image(fraction: (100 - available) / 100)
        let showAmount = UserDefaults.standard.object(forKey: SettingsKey.showReclaimableInMenuBar) as? Bool ?? true
        button.title = showAmount && !store.suspects.isEmpty ? " " + Format.bytes(store.reclaimableBytes) : ""
        button.toolTip = "Leftovers"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(header)
        StatusMenuBuilder(store: store).items().forEach(menu.addItem)
    }

    private func makeHeaderItem() -> NSMenuItem {
        let host = NSHostingView(rootView: MenuHeaderView(store: store))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let item = NSMenuItem()
        item.view = host
        return item
    }
}
