import Foundation

/// Locates the user-facing `.app` a process belongs to — Slack's renderer
/// helper belongs to `Slack.app`, Xcode's `swift-frontend` to `Xcode.app`.
enum AppBundle {
    /// Path of the outermost `.app` in `executablePath`, if it is a desktop app.
    static func outerPath(of executablePath: String) -> String? {
        guard ProcessKind.classify(path: executablePath) != .commandLine,
              let range = executablePath.range(of: ".app/") else { return nil }
        let path = String(executablePath[..<range.lowerBound]) + ".app"
        // Interpreter bundles inside frameworks (Python.app) are not apps.
        return path.contains(".framework/") ? nil : path
    }

    private static let names = NSCache<NSString, NSString>()

    /// The app's display name from its Info.plist, else its file name. Cached:
    /// it is read on every refresh.
    static func displayName(atPath path: String) -> String {
        if let cached = names.object(forKey: path as NSString) { return cached as String }
        let resolved = readDisplayName(atPath: path)
        names.setObject(resolved as NSString, forKey: path as NSString)
        return resolved
    }

    private static func readDisplayName(atPath path: String) -> String {
        let info = Bundle(path: path)?.infoDictionary
        let name = (info?["CFBundleDisplayName"] ?? info?["CFBundleName"]) as? String
        return name ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}
