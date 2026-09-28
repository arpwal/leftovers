import Foundation
import Testing
@testable import Leftovers

@Suite("Disk refresh, cache and warning")
struct DiskRefreshTests {
    private let gib = Fixture.gib

    @Test func refreshKeepsOldSizesUntilRemeasured() {
        var old = InstalledApp(path: "/Applications/A.app", name: "A", bundleID: "a")
        old.appBytes = 5; old.dataBytes = 6; old.cacheBytes = 7
        let fresh = InstalledApp(path: "/Applications/A.app", name: "A", bundleID: "a", cachePaths: ["/new"])
        let merged = DiskMerge.carryOver(old, into: fresh)
        #expect(merged.totalBytes == 18 && merged.cachePaths == ["/new"])
        #expect(DiskMerge.carryOver(nil, into: fresh).isMeasured == false)
    }

    @Test func largestKnownFolderIsMeasuredFirstAfterNewOnes() {
        let caches = [DiskStore.CacheItem(target: .npm, bytes: 1 * gib),
                      DiskStore.CacheItem(target: .xcodeDerivedData, bytes: 93 * gib),
                      DiskStore.CacheItem(target: .pip, bytes: nil)]
        let order = DiskMerge.largestFirst(caches: caches, apps: []).map { job -> CleanupTarget? in
            if case let .target(t) = job { return t } else { return nil }
        }
        #expect(order == [.pip, .xcodeDerivedData, .npm])
    }

    @Test func cacheRoundTrips() throws {
        let folder = try Scratch.folder("diskcache")
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let cache = DiskCache(url: URL(fileURLWithPath: folder + "/c.json"))
        let volumes = VolumeUsage(containerTotal: 100, containerFree: 10, system: 20, systemSupport: 5, data: 65)
        cache.save(.init(scannedAt: Date(timeIntervalSince1970: 1), breakdown: DiskBreakdown(volumes: volumes, appBytes: 3),
                         apps: [], caches: [.init(target: .npm, bytes: 42)]))
        let loaded = try #require(cache.load())
        #expect(loaded.breakdown?.bytes(.other) == 62 && loaded.caches.first?.bytes == 42)
    }

    @Test func unfinishedMeasurementIsNilNotZero() throws {
        #expect(DiskSize.total(of: []) == 0)
        let folder = try Scratch.folder("size")
        defer { try? FileManager.default.removeItem(atPath: folder) }
        FileManager.default.createFile(atPath: folder + "/f", contents: Data(count: 64 * 1024))
        #expect((DiskSize.total(of: [folder]) ?? 0) >= 64 * 1024)
    }

    @Test func lowDiskWarnsUnderTenPercentOncePerDay() {
        let now = Date()
        #expect(LowDiskWatcher.shouldWarn(free: 9 * gib, total: 100 * gib, lastWarned: nil, enabled: true, now: now))
        #expect(!LowDiskWatcher.shouldWarn(free: 11 * gib, total: 100 * gib, lastWarned: nil, enabled: true, now: now))
        #expect(!LowDiskWatcher.shouldWarn(free: 9 * gib, total: 100 * gib, lastWarned: now.addingTimeInterval(-3600), enabled: true, now: now))
        #expect(LowDiskWatcher.shouldWarn(free: 9 * gib, total: 100 * gib, lastWarned: now.addingTimeInterval(-90_000), enabled: true, now: now))
        #expect(!LowDiskWatcher.shouldWarn(free: 9 * gib, total: 100 * gib, lastWarned: nil, enabled: false, now: now))
    }

    @Test func diskFlagRoutes() {
        #expect(CommandRouter.command(for: ["x", "--disk"]) == .disk(json: false))
        #expect(CommandRouter.command(for: ["x", "--disk", "--json"]) == .disk(json: true))
    }
}
