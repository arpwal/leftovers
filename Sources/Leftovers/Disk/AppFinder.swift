import Foundation

/// Lists the apps you installed: `.app` bundles in /Applications (and one
/// folder deep, e.g. /Applications/Utilities) and ~/Applications. Apple's own
/// apps are left out: they ship with macOS and count as system.
enum AppFinder {
    static func installedApps(roots: [String] = defaultRoots) -> [InstalledApp] {
        var seen = Set<String>()
        return roots.flatMap(bundles(in:)).compactMap { path -> InstalledApp? in
            guard seen.insert(path).inserted else { return nil }
            let info = Bundle(path: path)?.infoDictionary
            let bundleID = info?["CFBundleIdentifier"] as? String
            if bundleID?.hasPrefix("com.apple.") == true { return nil }
            return InstalledApp(path: path, name: AppBundle.displayName(atPath: path), bundleID: bundleID)
        }
    }

    static var defaultRoots: [String] { ["/Applications", NSHomeDirectory() + "/Applications"] }

    private static func bundles(in root: String) -> [String] {
        children(of: root).flatMap { path -> [String] in
            if path.hasSuffix(".app") { return [path] }
            guard isPlainFolder(path) else { return [] }
            return children(of: path).filter { $0.hasSuffix(".app") }
        }
    }

    private static func children(of folder: String) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        return names.filter { !$0.hasPrefix(".") }.map { folder + "/" + $0 }.filter { !isSymlink($0) }
    }

    private static func isPlainFolder(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func isSymlink(_ path: String) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType) == .typeSymbolicLink
    }
}
