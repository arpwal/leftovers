import Foundation

/// Everything the strength score is computed from, in bytes.
struct StrengthInputs: Equatable {
    var totalMemory: UInt64
    var availableMemory: UInt64
    var swapUsed: UInt64
    var diskTotal: UInt64
    var diskFree: UInt64
    /// What a safe cleanup frees: likely leaks' RAM and swapped memory, and
    /// the safe-to-remove worktrees' disk space.
    var reclaimableResident: UInt64 = 0
    var reclaimableSwapped: UInt64 = 0
    var reclaimableDisk: UInt64 = 0
}

/// An approximate "how much of your Mac's strength is available" score, 0-100.
/// Deliberately simple and explained in the app:
///   50% memory available · 30% swap (fully bad at a quarter of RAM) · 20% disk free (fully good at 20%).
/// "After cleanup" is the same formula once likely leaks are quit and safe
/// worktrees removed.
enum SystemStrength {
    static let memoryWeight = 0.5, swapWeight = 0.3, diskWeight = 0.2
    static let swapLimitShareOfRAM = 0.25, healthyDiskFreeShare = 0.2

    struct Parts: Equatable {
        let memory: Double, swap: Double, disk: Double
        var score: Int { Int((memory * memoryWeight + swap * swapWeight + disk * diskWeight) * 100 + 0.5) }
    }

    static func parts(_ i: StrengthInputs) -> Parts {
        let memory = ratio(Double(i.availableMemory), Double(i.totalMemory))
        let swapLimit = Double(i.totalMemory) * swapLimitShareOfRAM
        let swap = 1 - ratio(Double(i.swapUsed), swapLimit)
        let disk = ratio(Double(i.diskFree), Double(i.diskTotal) * healthyDiskFreeShare)
        return Parts(memory: memory, swap: swap, disk: disk)
    }

    static func score(_ i: StrengthInputs) -> Int { parts(i).score }

    /// The same machine after a safe cleanup.
    static func afterCleanup(_ i: StrengthInputs) -> StrengthInputs {
        var after = i
        after.availableMemory = min(i.totalMemory, i.availableMemory + i.reclaimableResident)
        after.swapUsed = i.swapUsed > i.reclaimableSwapped ? i.swapUsed - i.reclaimableSwapped : 0
        after.diskFree = min(i.diskTotal, i.diskFree + i.reclaimableDisk)
        after.reclaimableResident = 0; after.reclaimableSwapped = 0; after.reclaimableDisk = 0
        return after
    }

    private static func ratio(_ value: Double, _ whole: Double) -> Double {
        guard whole > 0 else { return 0 }
        return min(max(value / whole, 0), 1)
    }
}

/// Size and free space of the volume holding the home folder.
enum DiskUsage {
    static func read(path: String = NSHomeDirectory()) -> (total: UInt64, free: UInt64)? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return (UInt64(total), UInt64(max(free, 0)))
    }
}
