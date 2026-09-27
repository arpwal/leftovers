import AppKit

/// The Disk section's data, filled in progressively: volume usage first
/// (instant), then the app list, then sizes as each one is measured.
@MainActor
final class DiskStore: ObservableObject {
    struct CacheItem: Identifiable, Hashable {
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
    @Published private(set) var breakdown: DiskBreakdown?
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var caches: [CacheItem] = []
    @Published private(set) var progress = Progress()
    @Published private(set) var lastScan: Date?
    @Published var lastActionMessage: String?
    private static let width = 4

    /// Developer caches worth offering (at least 1 MB), largest first.
    var cleanableCaches: [CacheItem] {
        caches.filter { ($0.bytes ?? 0) >= 1 << 20 }.sorted { ($0.bytes ?? 0) > ($1.bytes ?? 0) }
    }
    var cleanableBytes: UInt64 { cleanableCaches.compactMap(\.bytes).reduce(0, +) }

    func scanIfStale(maxAge: TimeInterval = 300) async {
        if let lastScan, Date().timeIntervalSince(lastScan) < maxAge { return }
        await scan()
    }

    func scan() async {
        guard !progress.isScanning else { return }
        progress = Progress(isScanning: true)
        let (volumes, found, targets) = await Task.detached(priority: .userInitiated) {
            let apps = AppDataLocator.attach(AppFinder.installedApps(), listing: AppDataLocator.listing())
            let targets = CleanupTarget.allCases.filter { FileManager.default.fileExists(atPath: $0.path()) }
            return (VolumeReader.read(), apps, targets)
        }.value
        if let volumes { breakdown = DiskBreakdown(volumes: volumes) }
        apps = markRunning(found)
        caches = targets.map { CacheItem(target: $0) }
        let jobs = targets.map(DiskMeasurement.target) + found.map {
            DiskMeasurement.app(path: $0.path, bundle: $0.path, data: $0.dataPaths, caches: $0.cachePaths)
        }
        progress.total = jobs.count
        await DiskMeasurement.runAll(jobs, width: Self.width) { self.apply($0) }
        progress.isScanning = false
        lastScan = Date()
    }

    func apply(_ result: DiskMeasurement.Result) {
        switch result {
        case let .target(target, bytes):
            if let i = caches.firstIndex(where: { $0.target == target }) { caches[i].bytes = bytes }
        case let .app(path, app, data, cacheBytes):
            if let i = apps.firstIndex(where: { $0.path == path }) {
                apps[i].appBytes = app; apps[i].dataBytes = data; apps[i].cacheBytes = cacheBytes
            }
            breakdown?.appBytes = apps.compactMap(\.appBytes).reduce(0, +)
            breakdown?.appDataBytes = apps.reduce(0) { $0 + ($1.dataBytes ?? 0) + ($1.cacheBytes ?? 0) }
        }
        progress.measured += 1
    }

    func refreshRunning() { apps = markRunning(apps) }

    func setMeasured(_ target: CleanupTarget, bytes: UInt64) {
        apply(.target(target, bytes)); progress.measured -= 1
    }

    func setCaches(of path: String, bytes: UInt64) {
        guard let i = apps.firstIndex(where: { $0.path == path }) else { return }
        apps[i].cacheBytes = bytes
        breakdown?.appDataBytes = apps.reduce(0) { $0 + ($1.dataBytes ?? 0) + ($1.cacheBytes ?? 0) }
    }

    private func markRunning(_ list: [InstalledApp]) -> [InstalledApp] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path })
        return list.map { var app = $0; app.isRunning = running.contains(URL(fileURLWithPath: $0.path).standardizedFileURL.path); return app }
    }
}
