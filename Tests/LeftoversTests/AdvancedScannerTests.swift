import Foundation
import Testing
@testable import Leftovers

@Suite("Advanced scanners read each tool's own output")
struct AdvancedScannerTests {
    @Test func dockerSystemDFBecomesThreeOffersAndOneKeptVolumeRow() {
        let text = """
        {"Active":"2","Reclaimable":"3.1GB (72%)","Size":"4.3GB","TotalCount":"9","Type":"Images"}
        {"Active":"1","Reclaimable":"12.5MB (40%)","Size":"31MB","TotalCount":"4","Type":"Containers"}
        {"Active":"1","Reclaimable":"0B","Size":"2.1GB","TotalCount":"3","Type":"Local Volumes"}
        {"Active":"0","Reclaimable":"812.4MB","Size":"812.4MB","TotalCount":"40","Type":"Build Cache"}
        """
        let items = DockerScanner.items(fromSystemDF: text)
        #expect(items.map(\.id) == ["docker:images", "docker:containers", "docker:volumes", "docker:build"])
        #expect(items[0].bytes == 3_100_000_000 && items[0].removal == .docker(.unusedImages))
        #expect(items[3].bytes == 812_400_000)
        let volumes = items[2]
        #expect(volumes.removal == nil && !volumes.canRemove)   // volumes can hold databases: never offered
    }

    @Test func humanBytes() {
        #expect(HumanBytes.parse("0B") == 0)
        #expect(HumanBytes.parse("512.5kB") == 512_500)
        #expect(HumanBytes.parse("1.5TB (10%)") == 1_500_000_000_000)
        #expect(HumanBytes.parse("lots") == nil)
    }

    @Test func deadSimulatorsAndRuntimes() {
        let devices = """
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-6":[
          {"udid":"A","name":"iPhone 16","state":"Shutdown","isAvailable":false,"dataPathSize":18337792}],
          "com.apple.CoreSimulator.SimRuntime.iOS-26-5":[
          {"udid":"B","name":"iPhone 17","state":"Booted","isAvailable":true,"dataPathSize":4096}]}}
        """
        let runtimes = """
        {"X":{"identifier":"X","runtimeIdentifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-5","version":"26.5",
              "sizeBytes":8494282293,"lastUsedAt":"2026-09-28T00:03:08Z","deletable":true}}
        """
        let items = SimulatorScanner.items(devices: Data(devices.utf8), runtimes: Data(runtimes.utf8))
        #expect(items.map(\.title) == ["iPhone 16", "iOS 26.5 runtime"])
        #expect(items[0].removal == .simulatorDevice(udid: "A") && items[0].canRemove)
        #expect(items[0].detail.hasPrefix("iOS 18.6"))
        // A runtime any simulator still uses is kept.
        #expect(items[1].bytes == 8494282293 && items[1].blocker != nil && !items[1].canRemove)
        let unused = SimulatorScanner.items(devices: Data(#"{"devices":{}}"#.utf8), runtimes: Data(runtimes.utf8))
        #expect(unused.first?.canRemove == true)
        #expect(!items.contains { $0.title == "iPhone 17" })   // available simulators are never offered
    }

    @Test func onlyTimeMachineSnapshotsAreOffered() {
        let listing = """
        Snapshots for volume group containing disk /:
        com.apple.TimeMachine.2026-09-27-101010.local
        com.apple.os.update-2BDD67A1
        com.apple.TimeMachine.2026-09-27-10; rm -rf ~.local
        """
        let items = SnapshotScanner.items(fromListing: listing)
        #expect(items.count == 3)
        #expect(items[0].removal == .timeMachineSnapshot(date: "2026-09-27-101010"))
        #expect(items[1].removal == nil && items[2].removal == nil)   // update snapshot; malformed name is never passed to tmutil
    }

    @Test func nodeModulesInUseIsBlockedAndMarkersDateTheInstall() throws {
        let root = try Scratch.folder("nm")
        defer { try? FileManager.default.removeItem(atPath: root) }
        let modules = root + "/app/node_modules"
        try FileManager.default.createDirectory(atPath: modules + "/left-pad/node_modules", withIntermediateDirectories: true)
        let marker = Date(timeIntervalSince1970: 1_700_000_000)
        FileManager.default.createFile(atPath: modules + "/.package-lock.json", contents: Data(), attributes: [.modificationDate: marker])
        #expect(NodeModulesScanner.find(in: root) == [modules])   // nested one pruned
        #expect(NodeModulesScanner.lastInstall(modules) == marker)
        let busy = NodeModulesScanner.item(for: modules, inUse: [root + "/app/src": "node"])
        #expect(busy.blocker == "In use by node" && !busy.canRemove)
        #expect(NodeModulesScanner.item(for: modules, inUse: [root + "/application": "node"]).canRemove)
    }
}

@Suite("AI models")
struct AIModelTests {
    private func manifest(_ digests: [(String, UInt64)]) -> Data {
        let layers = digests.map { "{\"digest\":\"\($0.0)\",\"size\":\($0.1)}" }.joined(separator: ",")
        return Data("{\"layers\":[\(layers)]}".utf8)
    }

    @Test func removingAnOllamaModelKeepsBlobsAnotherModelShares() throws {
        let root = try Scratch.folder("ollama")
        defer { try? FileManager.default.removeItem(atPath: root) }
        let lib = root + "/manifests/registry.ollama.ai/library"
        for model in ["llama", "qwen"] { try FileManager.default.createDirectory(atPath: "\(lib)/\(model)", withIntermediateDirectories: true) }
        try FileManager.default.createDirectory(atPath: root + "/blobs", withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: "\(lib)/llama/3b", contents: manifest([("sha256:shared", 10), ("sha256:llama", 20)]))
        FileManager.default.createFile(atPath: "\(lib)/qwen/7b", contents: manifest([("sha256:shared", 10), ("sha256:qwen", 30)]))
        for blob in ["shared", "llama", "qwen"] { FileManager.default.createFile(atPath: root + "/blobs/sha256-" + blob, contents: Data()) }

        let items = AIModelScanner.ollama(root: root)
        #expect(Set(items.map(\.title)) == ["llama:3b", "qwen:7b"])
        #expect(items.first { $0.title == "llama:3b" }?.bytes == 30)

        let outcome = RemovalRunner.removeOllama(name: "llama:3b", manifest: "\(lib)/llama/3b", root: root, serverRunning: false)
        #expect(outcome == .removed)
        #expect(!FileManager.default.fileExists(atPath: root + "/blobs/sha256-llama"))
        #expect(FileManager.default.fileExists(atPath: root + "/blobs/sha256-shared"))   // qwen still needs it
        #expect(AIModelScanner.ollama(root: root).map(\.title) == ["qwen:7b"])
    }

    @Test func huggingFaceFoldersBecomeNamedModels() throws {
        let home = try Scratch.folder("hf")
        defer { try? FileManager.default.removeItem(atPath: home) }
        let hub = home + "/.cache/huggingface/hub"
        for name in ["models--meta-llama--Llama-3.2-1B", "datasets--squad--v2", ".locks", "version.txt"] {
            try FileManager.default.createDirectory(atPath: hub + "/" + name, withIntermediateDirectories: true)
        }
        let items = AIModelScanner.huggingFace(home: home)
        #expect(items.map(\.title) == ["squad/v2", "meta-llama/Llama-3.2-1B"])
        #expect(items[1].removal == .folder(hub + "/models--meta-llama--Llama-3.2-1B") && items[1].measurePath != nil)
    }

    @Test func folderRemovalRefusesOutsideHome() {
        #expect(RemovalRunner.removeFolder("/usr/local", home: "/Users/nobody") != .removed)
    }
}
