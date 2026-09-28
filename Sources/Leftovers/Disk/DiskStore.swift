import AppKit

/// The Disk section's data. Opens instantly from the last scan; a refresh
/// re-reads the volumes (a tenth of a second) and re-measures folders in the
/// background, largest first, each row keeping its last size until its new
/// one lands. Refreshes at most every 30 minutes unless asked.
@MainActor
final class DiskStore: ObservableObject {
    struct CacheItem: Identifiable, Hashable, Codable {
        let target: CleanupTarget
        var bytes: UInt64?
        var id: CleanupTarget { target }
    }

    struct Progress: Equatable {
        var total = 0
        var measured = 0
        var isScanning = false
    }

    static let shared = DiskStore()
    nonisolated static let maxAge: TimeInterval = 30 * 60
    @Published private(set) var breakdown: DiskBreakdown?
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var caches: [CacheItem] = []
    @Published private(set) var progress = Progress()
    @Published private(set) var lastScan: Date?
    @Published var lastActionMessage: String?
    private let cache: DiskCache
    private static let width = 4

    init(cache: DiskCache = DiskCache()) {
        self.cache = cache
        guard let saved = cache.load() else { return }
        breakdown = saved.breakdown; apps = saved.apps; caches = saved.caches; lastScan = saved.scannedAt
    }

    /// Developer caches worth offering (at least 1 MB), largest first.
    var cleanableCaches: [CacheItem] {
        caches.filter { ($0.bytes ?? 0) >= 1 << 20 }.sorted { ($0.bytes ?? 0) > ($1.bytes ?? 0) }
    }
    var cleanableBytes: UInt64 { cleanableCaches.compactMap(\.bytes).reduce(0, +) }
    /// True only before anything was ever measured: afterwards old sizes stand in.
    var isFirstScan: Bool { progress.isScanning && lastScan == nil }

    func scanIfStale(maxAge: TimeInterval = DiskStore.maxAge) async {
        if let lastScan, Date().timeIntervalSince(lastScan) < maxAge {
            await refreshVolumes()
            return
        }
        await scan()
    }

    func refreshVolumes() async {
        guard let volumes = await Task.detached(priority: .userInitiated, operation: VolumeReader.read).value else { return }
        if breakdown == nil { breakdown = DiskBreakdown(volumes: volumes) } else { breakdown?.volumes = volumes }
    }

    func scan() async {
        guard !progress.isScanning else { return }
        progress = Progress(isScanning: true)
        await refreshVolumes()
        let (found, targets) = await Task.detached(priority: .userInitiated) {
            (AppDataLocator.attach(AppFinder.installedApps(), listing: AppDataLocator.listing()),
             CleanupTarget.allCases.filter { FileManager.default.fileExists(atPath: $0.path()) })
        }.value
        let oldApps = Dictionary(apps.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        let oldCaches = Dictionary(caches.map { ($0.target, $0.bytes) }, uniquingKeysWith: { a, _ in a })
        apps = markRunning(found.map { DiskMerge.carryOver(oldApps[$0.path], into: $0) })
        caches = targets.map { CacheItem(target: $0, bytes: oldCaches[$0] ?? nil) }
        recomputeTotals()
        let jobs = DiskMerge.largestFirst(caches: caches, apps: apps)
        progress.total = jobs.count
        await DiskMeasurement.runAll(jobs, width: Self.width) { self.apply($0) }
        progress.isScanning = false
        lastScan = Date()
        save()
    }

    func apply(_ result: DiskMeasurement.Result) {
        switch result {
        case let .target(target, bytes):
            if let i = caches.firstIndex(where: { $0.target == target }), let bytes { caches[i].bytes = bytes }
        case let .app(path, app, data, cacheBytes):
            if let i = apps.firstIndex(where: { $0.path == path }) {
                apps[i].appBytes = app ?? apps[i].appBytes
                apps[i].dataBytes = data ?? apps[i].dataBytes
                apps[i].cacheBytes = cacheBytes ?? apps[i].cacheBytes
            }
            recomputeTotals()
        }
        progress.measured += 1
    }

    func refreshRunning() { apps = markRunning(apps) }

    func setMeasured(_ target: CleanupTarget, bytes: UInt64) {
        if let i = caches.firstIndex(where: { $0.target == target }) { caches[i].bytes = bytes }
        save()
    }

    func setCaches(of path: String, bytes: UInt64) {
        guard let i = apps.firstIndex(where: { $0.path == path }) else { return }
        apps[i].cacheBytes = bytes
        recomputeTotals(); save()
    }

    private func recomputeTotals() {
        breakdown?.appBytes = apps.compactMap(\.appBytes).reduce(0, +)
        breakdown?.appDataBytes = apps.reduce(0) { $0 + ($1.dataBytes ?? 0) + ($1.cacheBytes ?? 0) }
    }

    private func save() {
        cache.save(.init(scannedAt: lastScan ?? Date(), breakdown: breakdown, apps: apps, caches: caches))
    }

    private func markRunning(_ list: [InstalledApp]) -> [InstalledApp] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path })
        return list.map { var app = $0; app.isRunning = running.contains(URL(fileURLWithPath: $0.path).standardizedFileURL.path); return app }
    }
}
