import AppKit
import SwiftUI

/// True only while `--snapshot` renders views offscreen. Offscreen capture
/// cannot draw window translucency, so a few surfaces paint a solid stand-in.
private struct IsSnapshotKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSnapshot: Bool {
        get { self[IsSnapshotKey.self] }
        set { self[IsSnapshotKey.self] = newValue }
    }
}

extension Color {
    /// Close to the translucent sidebar over a typical desktop, light and dark.
    static let snapshotSidebar = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.925, alpha: 1)
    })
}
