import Foundation

/// The ~/Library folders Leftovers looks in for an app's data. Containers
/// and Group Containers are deliberately skipped: macOS asks the user before
/// any app reads another app's container.
enum LibraryFolder: String, CaseIterable {
    case caches = "Caches"
    case applicationSupport = "Application Support"
    case logs = "Logs"
    case httpStorages = "HTTPStorages"
    case webKit = "WebKit"

    var holdsOnlyCaches: Bool { self == .caches }
}

/// Matches an app to its folders in ~/Library by exact name: its bundle ID
/// (com.tinyspeck.slackmacgap), that ID's updater cache (…ShipIt) or its
/// name (Slack). Exact only: a vendor folder like "Google" is never guessed
/// to belong to one app, so clearing an app's caches can't touch another's.
enum AppDataLocator {
    typealias Listing = [LibraryFolder: [String]]

    static func listing(library: String = NSHomeDirectory() + "/Library") -> Listing {
        Dictionary(uniqueKeysWithValues: LibraryFolder.allCases.map { folder in
            let names = (try? FileManager.default.contentsOfDirectory(atPath: library + "/" + folder.rawValue)) ?? []
            return (folder, names.filter { !$0.hasPrefix(".") })
        })
    }

    /// Fills `dataPaths` and `cachePaths`. Each folder goes to at most one app.
    static func attach(_ apps: [InstalledApp], listing: Listing,
                       library: String = NSHomeDirectory() + "/Library") -> [InstalledApp] {
        var claimed = Set<String>()
        return apps.map { app in
            var app = app
            let keys = matchKeys(for: app)
            for folder in LibraryFolder.allCases {
                for name in listing[folder] ?? [] where keys.contains(name.lowercased()) {
                    let path = library + "/" + folder.rawValue + "/" + name
                    guard claimed.insert(path).inserted else { continue }
                    if folder.holdsOnlyCaches { app.cachePaths.append(path) } else { app.dataPaths.append(path) }
                }
            }
            return app
        }
    }

    static func matchKeys(for app: InstalledApp) -> Set<String> {
        var keys: Set<String> = [app.name.lowercased()]
        let stem = ((app.path as NSString).lastPathComponent as NSString).deletingPathExtension.lowercased()
        keys.insert(stem)
        if let id = app.bundleID?.lowercased() { keys.formUnion([id, id + ".shipit"]) }
        return keys.filter { !$0.isEmpty }
    }
}
