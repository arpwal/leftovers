import Foundation

/// One app in /Applications with the data it keeps in ~/Library. Sizes are
/// nil until measured.
struct InstalledApp: Identifiable, Hashable {
    let path: String
    let name: String
    let bundleID: String?
    /// Support files, logs and web storage in ~/Library (not caches).
    var dataPaths: [String] = []
    /// Folders that only hold caches: safe to empty while the app is quit.
    var cachePaths: [String] = []
    var appBytes: UInt64?
    var dataBytes: UInt64?
    var cacheBytes: UInt64?
    var isRunning = false

    var id: String { path }
    var isMeasured: Bool { appBytes != nil && dataBytes != nil && cacheBytes != nil }
    var totalBytes: UInt64 { (appBytes ?? 0) + (dataBytes ?? 0) + (cacheBytes ?? 0) }
    var canClearCaches: Bool { !isRunning && (cacheBytes ?? 0) > 0 }

    // Sort keys (unmeasured sorts last).
    var sortName: String { name.lowercased() }
    var sortApp: UInt64 { appBytes ?? 0 }
    var sortData: UInt64 { dataBytes ?? 0 }
    var sortCaches: UInt64 { cacheBytes ?? 0 }
}
