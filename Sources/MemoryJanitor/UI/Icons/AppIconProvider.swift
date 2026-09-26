import AppKit

/// App logos read from the apps installed on this Mac (never downloaded),
/// cached for the life of the process.
@MainActor
enum AppIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    /// Logo of the app a process belongs to, or its executable's Finder icon.
    static func icon(for snapshot: ProcessSnapshot) -> NSImage {
        icon(atPath: AppBundle.outerPath(of: snapshot.executablePath) ?? snapshot.executablePath)
    }

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
