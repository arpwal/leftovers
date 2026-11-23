import Foundation
import LeftoversHelperKit

/// Samples fseventsd once per refresh: through the helper when it's allowed
/// (root reads the footprint and CPU time directly), otherwise through the
/// setuid `ps`/`top`. Keeps the previous CPU time (CPU% is the delta between
/// readings, like `CpuTracker`) and resets whenever fseventsd restarts.
actor FseventsdSampler {
    enum Sample: Equatable, Sendable {
        case notRunning
        case unavailable(String)
        case reading(FseventsdReading)
    }

    private struct CpuMark { let seconds: Double; let at: MonotonicStamp }
    /// `bytes` is nil when `top` failed; the attempt still counts, so it isn't retried every refresh.
    private struct FootprintMark { let bytes: UInt64?; let at: MonotonicStamp }
    /// What one source measured, before CPU% is derived.
    private struct Raw {
        let identity: FseventsdIdentity
        let residentBytes: UInt64
        let footprintBytes: UInt64?
        let cpuSeconds: Double
        let source: FseventsdReading.Source
    }

    private var identity: FseventsdIdentity?
    private var lastCpu: CpuMark?
    private var footprint: FootprintMark?

    func sample(useHelper: Bool) async -> Sample {
        let now = MonotonicStamp.now()
        if useHelper {
            switch await HelperClient.readFseventsd() {
            case let .reading(reading): return .reading(derive(fromHelper(reading), now: now))
            case .notRunning: forget(); return .notRunning
            case .unreachable: break // fall back to ps
            }
        }
        return sampleWithPs(now: now)
    }

    /// Drops the CPU and footprint memory (after a restart).
    func forget() {
        identity = nil
        lastCpu = nil
        footprint = nil
    }

    private func sampleWithPs(now: MonotonicStamp) -> Sample {
        guard let current = locate() else { forget(); return .notRunning }
        guard let stats = FseventsdStatsReader.psStats(pid: current.pid) else { return .unavailable("ps couldn't read it") }
        if current != identity { forget() }
        refreshFootprint(pid: current.pid, now: now)
        return .reading(derive(Raw(identity: current, residentBytes: stats.residentBytes, footprintBytes: footprint?.bytes,
                                   cpuSeconds: stats.cpuSeconds, source: .ps), now: now))
    }

    private func fromHelper(_ reading: HelperReading) -> Raw {
        Raw(identity: reading.identity, residentBytes: reading.residentBytes, footprintBytes: reading.footprintBytes,
            cpuSeconds: Double(reading.cpuTimeNanos) / 1_000_000_000, source: .helper)
    }

    /// Adds CPU% from the previous reading of the same process.
    private func derive(_ raw: Raw, now: MonotonicStamp) -> FseventsdReading {
        if raw.identity != identity { lastCpu = nil; identity = raw.identity }
        let interval = lastCpu.map { $0.at.elapsed(until: now) }
        let cpu = lastCpu.flatMap { mark -> Double? in
            guard let interval, interval > 0, raw.cpuSeconds >= mark.seconds else { return nil }
            return (raw.cpuSeconds - mark.seconds) / interval * 100
        }
        lastCpu = CpuMark(seconds: raw.cpuSeconds, at: now)
        return FseventsdReading(identity: raw.identity, residentBytes: raw.residentBytes, footprintBytes: raw.footprintBytes,
                                cpuPercent: cpu, interval: interval, source: raw.source, takenAt: now)
    }

    private func locate() -> FseventsdIdentity? {
        if let identity, FseventsdProcess.isAlive(identity) { return identity }
        return FseventsdProcess.locate()
    }

    private func refreshFootprint(pid: pid_t, now: MonotonicStamp) {
        if let footprint, footprint.at.elapsed(until: now) < Thresholds.fseventsdFootprintInterval { return }
        footprint = FootprintMark(bytes: FseventsdStatsReader.footprint(pid: pid) ?? footprint?.bytes, at: now)
    }
}
