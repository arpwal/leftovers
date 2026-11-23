import Foundation
import LeftoversHelperKit

/// Samples fseventsd once per refresh. Keeps the previous CPU time (CPU% is
/// the delta between readings, like `CpuTracker`) and a cached footprint.
/// State resets whenever fseventsd restarts (new pid or start time).
actor FseventsdSampler {
    private struct CpuMark { let seconds: Double; let at: Date }
    /// `bytes` is nil when `top` failed; the attempt still counts, so it isn't retried every refresh.
    private struct FootprintMark { let bytes: UInt64?; let at: Date }

    private var identity: FseventsdIdentity?
    private var lastCpu: CpuMark?
    private var footprint: FootprintMark?

    /// nil when fseventsd isn't running or `ps` couldn't read it.
    func sample(now: Date = Date()) -> FseventsdReading? {
        guard let current = locate() else { forget(); return nil }
        if current != identity { forget(); identity = current }
        guard let stats = FseventsdStatsReader.psStats(pid: current.pid) else { return nil }
        let interval = lastCpu.map { now.timeIntervalSince($0.at) }
        let cpu = lastCpu.flatMap { cpuPercent(from: $0, to: stats.cpuSeconds, at: now) }
        lastCpu = CpuMark(seconds: stats.cpuSeconds, at: now)
        refreshFootprint(pid: current.pid, now: now)
        return FseventsdReading(identity: current, residentBytes: stats.residentBytes, footprintBytes: footprint?.bytes,
                                cpuPercent: cpu, interval: interval, takenAt: now)
    }

    /// Re-reads the footprint after a restart, so the next reading is fresh.
    func forget() {
        identity = nil
        lastCpu = nil
        footprint = nil
    }

    private func locate() -> FseventsdIdentity? {
        if let identity, FseventsdProcess.isAlive(identity) { return identity }
        return FseventsdProcess.locate()
    }

    private func cpuPercent(from mark: CpuMark, to seconds: Double, at now: Date) -> Double? {
        let elapsed = now.timeIntervalSince(mark.at)
        guard elapsed > 0, seconds >= mark.seconds else { return nil }
        return (seconds - mark.seconds) / elapsed * 100
    }

    private func refreshFootprint(pid: pid_t, now: Date) {
        if let footprint, now.timeIntervalSince(footprint.at) < Thresholds.fseventsdFootprintInterval { return }
        footprint = FootprintMark(bytes: FseventsdStatsReader.footprint(pid: pid) ?? footprint?.bytes, at: now)
    }
}
