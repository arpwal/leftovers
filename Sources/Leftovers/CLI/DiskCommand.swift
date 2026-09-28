import Foundation

/// `Leftovers --disk [--json]`: the startup disk split into system, apps and
/// yours (apps from the app's last scan, if any), plus every developer cache
/// that rebuilds itself and how big it is. Read-only.
enum DiskCommand {
    struct Output: Encodable {
        struct Cache: Encodable { let name, path: String; let bytes: UInt64? }
        let totalBytes, freeBytes, systemBytes, appBytes, yoursBytes: UInt64
        let appsMeasuredAt: Date?
        let caches: [Cache]
    }

    static func runAndExit(json: Bool) {
        guard let volumes = VolumeReader.read() else { Usage.fail("Couldn't read the startup disk.") }
        let saved = DiskCache().load()
        var breakdown = DiskBreakdown(volumes: volumes)
        breakdown.appBytes = saved?.breakdown?.appBytes ?? 0
        breakdown.appDataBytes = saved?.breakdown?.appDataBytes ?? 0
        let targets = CleanupTarget.allCases.filter { FileManager.default.fileExists(atPath: $0.path()) }
        var sizes = [UInt64?](repeating: nil, count: targets.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: targets.count) { i in
            let size = DiskSize.total(of: [targets[i].path()])
            lock.lock(); sizes[i] = size; lock.unlock()
        }
        let output = Output(totalBytes: volumes.containerTotal, freeBytes: volumes.containerFree,
                            systemBytes: breakdown.bytes(DiskOwner.system), appBytes: breakdown.bytes(DiskOwner.apps),
                            yoursBytes: breakdown.bytes(DiskOwner.yours), appsMeasuredAt: saved?.scannedAt,
                            caches: zip(targets, sizes).map { .init(name: $0.title, path: $0.path(), bytes: $1) }
                                .sorted { ($0.bytes ?? 0) > ($1.bytes ?? 0) })
        print(json ? encode(output) : text(output))
        exit(0)
    }

    private static func encode(_ output: Output) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(output)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    private static func text(_ o: Output) -> String {
        var lines = ["Disk \(Format.bytes(o.totalBytes)), \(Format.bytes(o.freeBytes)) free",
                     "  System \(Format.bytes(o.systemBytes)) · Apps \(Format.bytes(o.appBytes))\(o.appsMeasuredAt == nil ? " (open the app's Disk section to measure)" : "") · Yours \(Format.bytes(o.yoursBytes))",
                     "", "Developer caches (rebuild themselves):"]
        lines += o.caches.map { "  \($0.bytes.map(Format.bytes) ?? "?")\t\($0.name)" }
        return lines.joined(separator: "\n")
    }
}
