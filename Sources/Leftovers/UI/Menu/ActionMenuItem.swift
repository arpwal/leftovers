import AppKit

/// An NSMenuItem that runs a closure, so menus can be built declaratively.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, key: String = "", image: NSImage? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        self.target = self
        self.image = image
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}
