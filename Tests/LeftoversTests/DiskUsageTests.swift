import Foundation
import Testing
@testable import Leftovers

@Suite("Disk usage: system vs apps vs yours")
struct DiskUsageTests {
    private let gib = Fixture.gib

    /// The shape `diskutil apfs list -plist` returns for one container.
    private var container: [String: Any] {
        func volume(_ role: String, _ gb: UInt64) -> [String: Any] {
            ["Roles": [role], "CapacityInUse": NSNumber(value: gb * gib)]
        }
        return ["CapacityCeiling": NSNumber(value: 1000 * gib), "CapacityFree": NSNumber(value: 30 * gib),
                "Volumes": [volume("System", 18), volume("Preboot", 17), volume("Recovery", 2),
                            volume("Update", 1), volume("VM", 14), volume("Data", 900)]]
    }

    @Test func splitsVolumesIntoMacOSSupportAndData() throws {
        let usage = try #require(VolumeReader.usage(from: container))
        #expect(usage.system == 18 * gib)
        #expect(usage.systemSupport == 34 * gib)   // preboot + recovery + update + swap
        #expect(usage.data == 900 * gib)
        #expect(usage.containerTotal == 1000 * gib && usage.containerFree == 30 * gib)
    }

    @Test func slicesAlwaysAddUpToTheDisk() throws {
        var breakdown = DiskBreakdown(volumes: try #require(VolumeReader.usage(from: container)))
        breakdown.appBytes = 40 * gib
        breakdown.appDataBytes = 60 * gib
        #expect(breakdown.bytes(.other) == 800 * gib)
        #expect(breakdown.bytes(DiskOwner.system) == 52 * gib)
        #expect(breakdown.bytes(DiskOwner.apps) == 100 * gib)
        let sum = DiskArea.allCases.reduce(UInt64(0)) { $0 + breakdown.bytes($1) }
        #expect(sum == 982 * gib)   // 1000 minus the 18 GB APFS keeps for itself and snapshots
    }

    @Test func measuringMoreThanTheDataVolumeNeverUnderflows() throws {
        var breakdown = DiskBreakdown(volumes: try #require(VolumeReader.usage(from: container)))
        breakdown.appBytes = 950 * gib
        #expect(breakdown.bytes(.other) == 0)
    }

    @Test func malformedContainerIsNil() {
        #expect(VolumeReader.usage(from: ["Volumes": []]) == nil)
    }
}

@Suite("App data is matched exactly")
struct AppDataLocatorTests {
    private let library = "/L"
    private let slack = InstalledApp(path: "/Applications/Slack.app", name: "Slack", bundleID: "com.tinyspeck.slackmacgap")
    private let chrome = InstalledApp(path: "/Applications/Google Chrome.app", name: "Google Chrome", bundleID: "com.google.Chrome")

    @Test func findsDataAndCachesByBundleIDAndName() throws {
        let listing: AppDataLocator.Listing = [
            .caches: ["com.tinyspeck.slackmacgap", "com.tinyspeck.slackmacgap.ShipIt", "Google"],
            .applicationSupport: ["Slack", "Google"],
            .logs: ["Slack"],
        ]
        let apps = AppDataLocator.attach([slack, chrome], listing: listing, library: library)
        let found = try #require(apps.first)
        #expect(Set(found.cachePaths) == ["/L/Caches/com.tinyspeck.slackmacgap", "/L/Caches/com.tinyspeck.slackmacgap.ShipIt"])
        #expect(Set(found.dataPaths) == ["/L/Application Support/Slack", "/L/Logs/Slack"])
        // A vendor folder is never guessed to be one app's: clearing Chrome's caches can't touch Google Drive's.
        #expect(apps[1].cachePaths.isEmpty && apps[1].dataPaths.isEmpty)
    }

    @Test func aFolderBelongsToOneAppOnly() {
        let twin = InstalledApp(path: "/Applications/Other/Slack.app", name: "Slack", bundleID: "com.example.slack")
        let apps = AppDataLocator.attach([slack, twin], listing: [.applicationSupport: ["Slack"]], library: library)
        #expect(apps[0].dataPaths == ["/L/Application Support/Slack"])
        #expect(apps[1].dataPaths.isEmpty)
    }

    @Test func onlyTheCachesFolderCountsAsClearable() {
        let apps = AppDataLocator.attach([slack], listing: [.webKit: ["com.tinyspeck.slackmacgap"], .httpStorages: ["com.tinyspeck.slackmacgap"]], library: library)
        #expect(apps[0].cachePaths.isEmpty)
        #expect(apps[0].dataPaths.count == 2)
    }

    @Test func appFinderSkipsAppleAppsAndSymlinks() throws {
        let root = try Scratch.folder("apps")
        defer { try? FileManager.default.removeItem(atPath: root) }
        try Scratch.app(at: root + "/Mine.app", id: "com.example.mine")
        try Scratch.app(at: root + "/Utilities/Tool.app", id: "com.example.tool")
        try Scratch.app(at: root + "/Notes.app", id: "com.apple.Notes")
        try FileManager.default.createSymbolicLink(atPath: root + "/Link.app", withDestinationPath: root + "/Mine.app")
        let names = Set(AppFinder.installedApps(roots: [root]).map(\.bundleID))
        #expect(names == ["com.example.mine", "com.example.tool"])
    }
}

@Suite("Cache cleanup never reaches past the cache")
struct CachePurgerTests {
    @Test func refusesOutsideHomeLinksAndFiles() throws {
        let home = try Scratch.folder("home")
        defer { try? FileManager.default.removeItem(atPath: home) }
        try FileManager.default.createDirectory(atPath: home + "/cache", withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: home + "/file", contents: Data())
        try FileManager.default.createSymbolicLink(atPath: home + "/link", withDestinationPath: home + "/cache")
        #expect(CachePurger.validate("/tmp", home: home) == .outsideHome)
        #expect(CachePurger.validate(home, home: home) == .outsideHome)
        #expect(CachePurger.validate(home + "/cache/../..", home: home) == .outsideHome)
        #expect(CachePurger.validate(home + "/link", home: home) == .isLink)
        #expect(CachePurger.validate(home + "/file", home: home) == .notAFolder)
        #expect(CachePurger.validate(home + "/cache", home: home) == nil)
    }

    @Test func emptiesContentsKeepsFolderAndLeavesLinkTargetsAlone() throws {
        let home = try Scratch.folder("home")
        let outside = try Scratch.folder("outside")
        defer { [home, outside].forEach { try? FileManager.default.removeItem(atPath: $0) } }
        let cache = home + "/cache"
        try FileManager.default.createDirectory(atPath: cache + "/nested", withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: cache + "/nested/blob", contents: Data(count: 4096))
        FileManager.default.createFile(atPath: outside + "/precious", contents: Data("keep".utf8))
        try FileManager.default.createSymbolicLink(atPath: cache + "/escape", withDestinationPath: outside)
        let result = try CachePurger.empty(cache, home: home).get()
        #expect(result == .init(removed: 2, failed: 0))
        #expect(try FileManager.default.contentsOfDirectory(atPath: cache).isEmpty)
        #expect(FileManager.default.fileExists(atPath: outside + "/precious"))
    }
}

@Suite("Developer caches")
struct CleanupTargetTests {
    @Test func everyTargetIsAUniqueFolderInsideHome() {
        let paths = CleanupTarget.allCases.map { $0.path(home: "/Users/me") }
        #expect(Set(paths).count == paths.count)
        #expect(paths.allSatisfy { $0.hasPrefix("/Users/me/") && !$0.contains("..") })
        #expect(CleanupTarget.allCases.allSatisfy { !$0.usedBy.isEmpty })
    }

    @Test func aRunningToolKeepsItsCache() {
        let items = [DiskStore.CacheItem(target: .xcodeDerivedData, bytes: 1), DiskStore.CacheItem(target: .npm, bytes: 1)]
        let (ready, busy) = DiskActions.split(items, running: ["xcodebuild", "node"])
        #expect(ready.map(\.target) == [.npm])   // node alone doesn't hold npm's cache
        #expect(busy.map(\.target) == [.xcodeDerivedData])
        #expect(CleanupTarget.xcodeDerivedData.blocker(running: ["Xcode"]) == "Xcode")
    }
}

/// Real folders in a temp directory, resolved (macOS's /var is /private/var).
enum Scratch {
    static func folder(_ name: String) throws -> String {
        let path = NSTemporaryDirectory() + "leftovers-\(name)-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().path.replacingOccurrences(of: "/var/", with: "/private/var/")
    }

    static func app(at path: String, id: String) throws {
        try FileManager.default.createDirectory(atPath: path + "/Contents", withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": (path as NSString).lastPathComponent]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: URL(fileURLWithPath: path + "/Contents/Info.plist"))
    }
}
