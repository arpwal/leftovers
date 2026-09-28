import Foundation

/// Pure helpers for refreshing a disk scan on top of the last one.
enum DiskMerge {
    /// A re-found app keeps its last sizes until they're re-measured; its
    /// folders come from the new listing.
    static func carryOver(_ old: InstalledApp?, into fresh: InstalledApp) -> InstalledApp {
        guard let old else { return fresh }
        var app = fresh
        app.appBytes = old.appBytes; app.dataBytes = old.dataBytes; app.cacheBytes = old.cacheBytes
        return app
    }

    /// Measurement jobs, largest last-known size first: the slow `du` of a
    /// 90 GB folder starts at once instead of holding up the end. Never-measured
    /// items go first of all, since they have nothing to show yet.
    static func largestFirst(caches: [DiskStore.CacheItem], apps: [InstalledApp]) -> [DiskMeasurement] {
        let weighted: [(UInt64, DiskMeasurement)] =
            caches.map { ($0.bytes ?? .max, DiskMeasurement.target($0.target)) } +
            apps.map { app in
                (app.isMeasured ? app.totalBytes : .max,
                 DiskMeasurement.app(path: app.path, bundle: app.path, data: app.dataPaths, caches: app.cachePaths))
            }
        return weighted.enumerated().sorted { ($0.element.0, -$0.offset) > ($1.element.0, -$1.offset) }.map(\.element.1)
    }
}
