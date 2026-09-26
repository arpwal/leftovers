import AppKit
import SwiftUI

/// Window styles. The dashboard and welcome windows have no title bar: the
/// content runs to the top edge and the traffic lights float over it.
@MainActor
enum WindowFactory {
    static func dashboard<V: View>(_ view: V, delegate: NSWindowDelegate) -> NSWindow {
        let window = make(view, size: NSSize(width: 1100, height: 700), delegate: delegate,
                          style: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
        // Enforce only a minimum: by default the hosting controller would
        // shrink the window to the content's smallest size.
        (window.contentViewController as? NSHostingController<V>)?.sizingOptions = [.minSize]
        window.setContentSize(NSSize(width: 1100, height: 700))
        window.center()
        hideTitleBar(window)
        window.contentMinSize = NSSize(width: 900, height: 560)
        window.setFrameAutosaveName("LeftoversDashboard")
        return window
    }

    static func welcome<V: View>(_ view: V, delegate: NSWindowDelegate) -> NSWindow {
        let window = make(view, size: NSSize(width: 580, height: 600), delegate: delegate,
                          style: [.titled, .closable, .fullSizeContentView])
        hideTitleBar(window)
        window.isMovableByWindowBackground = true
        return window
    }

    static func settings<V: View>(_ view: V, delegate: NSWindowDelegate) -> NSWindow {
        let window = make(view, size: NSSize(width: 500, height: 520), delegate: delegate, style: [.titled, .closable])
        window.title = "Settings"
        return window
    }

    private static func make<V: View>(_ view: V, size: NSSize, delegate: NSWindowDelegate,
                                      style: NSWindow.StyleMask) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: style,
                              backing: .buffered, defer: false)
        window.contentViewController = NSHostingController(rootView: view)
        window.isReleasedWhenClosed = false
        window.delegate = delegate
        window.center()
        return window
    }

    private static func hideTitleBar(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }
}
