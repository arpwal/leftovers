import Foundation
import LeftoversHelperKit

/// Sustained CPU, defined in time rather than samples (the refresh interval
/// is configurable): remembers when CPU first went over the limit for this
/// fseventsd, and forgets on any reading under it or a new pid.
struct CpuOverTracker: Equatable, Sendable {
    private(set) var identity: FseventsdIdentity?
    private(set) var overSince: MonotonicStamp?

    mutating func update(with reading: FseventsdReading, limit: Double) {
        if reading.identity != identity {
            identity = reading.identity
            overSince = nil
        }
        guard let cpu = reading.cpuPercent else { return } // first reading: no CPU% yet
        if cpu > limit {
            // A reading averages the interval before it, so it's been over since then.
            overSince = overSince ?? reading.takenAt.shifted(by: -(reading.interval ?? 0))
        } else {
            overSince = nil
        }
    }

    mutating func reset() {
        identity = nil
        overSince = nil
    }

    func overFor(at now: MonotonicStamp) -> TimeInterval {
        overSince.map { $0.elapsed(until: now) } ?? 0
    }
}
