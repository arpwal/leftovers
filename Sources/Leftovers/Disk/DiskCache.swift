import Foundation

/// The last disk scan, saved so the Disk section opens with numbers at once
/// and only re-measures in the background.
struct DiskCache {
    var url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Leftovers/disk-cache.json")

    struct Snapshot: Codable {
        let scannedAt: Date
        let breakdown: DiskBreakdown?
        let apps: [InstalledApp]
        let caches: [DiskStore.CacheItem]
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    func save(_ snapshot: Snapshot) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
