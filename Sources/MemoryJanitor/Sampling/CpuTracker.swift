import Foundation

/// Derives CPU% per process by diffing cumulative CPU time between samples.
/// Keyed by `ProcessIdentity` so a reused pid never inherits a stale reading.
struct CpuTracker {
    private var previous: [ProcessIdentity: UInt64] = [:]
    private var previousSampleDate: Date?

    /// Returns CPU% for each snapshot (nil when there is no earlier reading),
    /// then remembers this sample for the next call.
    mutating func update(with snapshots: [ProcessSnapshot], at date: Date) -> [ProcessIdentity: Double] {
        var percents: [ProcessIdentity: Double] = [:]
        if let last = previousSampleDate {
            let elapsedNanos = date.timeIntervalSince(last) * 1_000_000_000
            for snapshot in snapshots {
                guard elapsedNanos > 0, let before = previous[snapshot.identity],
                      snapshot.cpuTimeNanos >= before else { continue }
                percents[snapshot.identity] = Double(snapshot.cpuTimeNanos - before) / elapsedNanos * 100
            }
        }
        previous = Dictionary(snapshots.map { ($0.identity, $0.cpuTimeNanos) }, uniquingKeysWith: { a, _ in a })
        previousSampleDate = date
        return percents
    }
}
