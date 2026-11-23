import Foundation

/// Recent CPU readings, to tell sustained load from a spike. Each reading
/// is the average over the interval before it, so the window is covered
/// from (first reading's time − its interval) to the last reading.
struct CpuWindow: Equatable {
    struct Sample: Equatable {
        let percent: Double
        let interval: TimeInterval
        let at: Date
    }

    private(set) var samples: [Sample] = []

    /// Adds a reading and drops ones that ended before the window began.
    mutating func add(_ sample: Sample, window: TimeInterval) {
        samples.append(sample)
        samples.removeAll { sample.at.timeIntervalSince($0.at) > window }
    }

    mutating func reset() { samples.removeAll() }

    /// True when the readings cover the whole window and every one is above `limit`.
    func isSustained(above limit: Double, for window: TimeInterval) -> Bool {
        guard let first = samples.first, let last = samples.last else { return false }
        let covered = last.at.timeIntervalSince(first.at) + first.interval
        return covered >= window && samples.allSatisfy { $0.percent > limit }
    }

    /// How long CPU has been above `limit` without a dip, up to the window.
    func timeAbove(_ limit: Double) -> TimeInterval {
        guard let last = samples.last else { return 0 }
        let run = samples.reversed().prefix { $0.percent > limit }
        guard let earliest = run.last else { return 0 }
        return last.at.timeIntervalSince(earliest.at) + earliest.interval
    }
}
