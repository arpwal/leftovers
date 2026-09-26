import AppKit

/// App logos read from the apps installed on this Mac (never downloaded),
/// cached for the life of the process.
@MainActor
enum AppIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    private static let terminalPath = "/System/Applications/Utilities/Terminal.app"

    /// Logo of the app a process belongs to. Command-line tools get Terminal's
    /// icon and macOS helpers a gear, both clearer than a blank document.
    static func icon(for snapshot: ProcessSnapshot) -> NSImage {
        if let app = AppBundle.outerPath(of: snapshot.executablePath) { return icon(atPath: app) }
        switch snapshot.kind {
        case .commandLine: return icon(atPath: terminalPath)
        case .systemBinary, .xpcHelper: return systemHelperIcon
        case .appBundle: return icon(atPath: snapshot.executablePath)
        }
    }

    private static let systemHelperIcon: NSImage =
        NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "macOS helper") ?? NSImage()

    static func icon(atPath path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: path as NSString)
        return image
    }

    /// Logo of the desktop app that ships a coding agent (Claude, ChatGPT…),
    /// when that app is installed.
    static func icon(for agent: AgentKind) -> NSImage? {
        for bundleID in agent.companionBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return icon(atPath: url.path)
            }
        }
        return nil
    }

    /// A copy sized for menus (NSMenu draws images at their own size).
    static func menuSized(_ image: NSImage, side: CGFloat = 16) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: side, height: side)
        return copy
    }
}
