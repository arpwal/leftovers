import Foundation

/// The numbers behind the Overview section, gathered from the live memory
/// reading, the disk, the worktree scan and the scheduled jobs.
struct OverviewModel {
    let inputs: StrengthInputs
    let leakCount: Int
    let leakBytes: UInt64
    let safeWorktreeCount: Int
    let worktreeBytes: UInt64
    let worktreesMeasured: Bool
    let cacheBytes: UInt64
    let cachesMeasured: Bool
    let duplicateServerBytes: UInt64
    let duplicateServerCount: Int
    let failingJobs: Int

    var now: Int { SystemStrength.score(inputs) }
    var after: Int { SystemStrength.score(SystemStrength.afterCleanup(inputs)) }

    @MainActor
    static func make(store: MonitorStore, worktrees: WorktreeStore, jobs: ScheduledStore, caches: DiskStore,
                     disk: (total: UInt64, free: UInt64)?) -> OverviewModel? {
        guard let report = store.report else { return nil }
        let system = report.system
        let leaks = store.suspects
        let resident = leaks.reduce(UInt64(0)) { $0 + $1.snapshot.residentBytes }
        let swapped = leaks.reduce(UInt64(0)) {
            $0 + ($1.snapshot.footprintBytes > $1.snapshot.residentBytes ? $1.snapshot.footprintBytes - $1.snapshot.residentBytes : 0)
        }
        let safe = worktrees.safe
        let worktreeBytes = safe.compactMap(\.sizeBytes).reduce(0, +)
        let inputs = StrengthInputs(
            totalMemory: system.totalBytes,
            availableMemory: system.totalBytes / 100 * UInt64(max(system.availablePercent, 0)),
            swapUsed: system.swapUsedBytes,
            diskTotal: disk?.total ?? 0, diskFree: disk?.free ?? 0,
            reclaimableResident: resident, reclaimableSwapped: swapped,
            reclaimableDisk: worktreeBytes + caches.cleanableBytes)
        return OverviewModel(
            inputs: inputs, leakCount: leaks.count, leakBytes: store.reclaimableBytes,
            safeWorktreeCount: safe.count, worktreeBytes: worktreeBytes,
            worktreesMeasured: !worktrees.progress.isScanning && worktrees.lastScan != nil,
            cacheBytes: caches.cleanableBytes, cachesMeasured: !caches.progress.isScanning && caches.lastScan != nil,
            duplicateServerBytes: report.duplicateToolServers.reduce(0) { $0 + $1.totalFootprint },
            duplicateServerCount: report.duplicateToolServers.reduce(0) { $0 + $1.processCount },
            failingJobs: jobs.failingCount)
    }
}
