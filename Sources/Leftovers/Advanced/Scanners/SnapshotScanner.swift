import Foundation

/// Local snapshots on the startup disk, and space macOS will free by itself.
/// Only Time Machine's own snapshots are offered; macOS update snapshots are
/// shown for information (macOS removes them).
enum SnapshotScanner {
    static func scan() -> ToolReport {
        let listing = Git.run(executable: "/usr/bin/tmutil", ["listlocalsnapshots", "/"], timeout: 20) ?? ""
        var items = items(fromListing: listing)
        if let purgeable = purgeableBytes(), purgeable > 0 {
            items.insert(CleanableItem(id: "purgeable", title: "Purgeable space",
                                       detail: "Caches and snapshots macOS frees on its own when an app needs room.",
                                       bytes: purgeable), at: 0)
        }
        return ToolReport(items: items, notice: items.isEmpty ? "No local snapshots." : nil)
    }

    /// Pure: parses `tmutil listlocalsnapshots /`.
    static func items(fromListing text: String) -> [CleanableItem] {
        text.split(separator: "\n").map(String.init).filter { $0.hasPrefix("com.apple.") }.map { name in
            if let date = timeMachineDate(name) {
                return CleanableItem(id: name, title: "Time Machine snapshot",
                                     detail: "Taken \(date). Your backups on the backup disk are kept.",
                                     lastUsed: parse(date), removal: .timeMachineSnapshot(date: date))
            }
            return CleanableItem(id: name, title: "macOS update snapshot", detail: "macOS removes it after the update settles.")
        }
    }

    /// "com.apple.TimeMachine.2026-09-27-101010.local" → "2026-09-27-101010".
    static func timeMachineDate(_ name: String) -> String? {
        let prefix = "com.apple.TimeMachine.", suffix = ".local"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
        let date = String(name.dropFirst(prefix.count).dropLast(suffix.count))
        return date.range(of: #"^\d{4}-\d{2}-\d{2}-\d{6}$"#, options: .regularExpression) != nil ? date : nil
    }

    static func parse(_ date: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.date(from: date)
    }

    static func purgeableBytes() -> UInt64? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let plain = v.volumeAvailableCapacity, let important = v.volumeAvailableCapacityForImportantUsage else { return nil }
        return important > Int64(plain) ? UInt64(important - Int64(plain)) : 0
    }
}
