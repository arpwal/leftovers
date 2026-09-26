import Foundation

/// Combines the protection policy and leak detector into one verdict per process.
///
/// Order is the safety guarantee:
///   1. hard protection (other users, core macOS, this app, your list) — final.
///   2. macOS binaries: killable ONLY if an on-demand XPC helper is hoarding.
///   3. everything else: suspect if a leak rule fires, otherwise normal.
struct ProcessClassifier {
    let policy: ProtectionPolicy

    func classify(_ snapshots: [ProcessSnapshot], cpu: [ProcessIdentity: Double]) -> [ClassifiedProcess] {
        let detector = LeakDetector(ancestry: AncestryIndex(snapshots))
        return snapshots.map { snapshot in
            let percent = cpu[snapshot.identity]
            return ClassifiedProcess(
                snapshot: snapshot,
                cpuPercent: percent,
                verdict: verdict(for: snapshot, cpuPercent: percent, detector: detector)
            )
        }
    }

    private func verdict(for snapshot: ProcessSnapshot, cpuPercent: Double?, detector: LeakDetector) -> ProcessVerdict {
        if let reason = policy.hardProtection(for: snapshot) { return .protected(reason) }
        let leak = detector.detect(snapshot, cpuPercent: cpuPercent)
        if policy.isSystemOwned(snapshot) {
            if snapshot.kind == .xpcHelper, let leak, case .hoardingSwappedMemory = leak {
                return .suspect(leak)
            }
            return .protected(.systemBinary)
        }
        return leak.map(ProcessVerdict.suspect) ?? .normal
    }
}
