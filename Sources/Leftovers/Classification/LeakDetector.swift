import Foundation

/// Heuristics that separate leaked memory from memory doing useful work.
/// Each rule requires the process to be idle when CPU is known; with no CPU
/// reading yet (first sample) idleness-based rules stay silent.
struct LeakDetector {
    let ancestry: AncestryIndex

    /// Runtimes that power dev servers, scripts and agent tooling. Restricting
    /// the "detached" rule to these keeps legit launchd services (postgres,
    /// redis via `brew services`) from being flagged.
    static let devRuntimes: Set<String> = [
        "node", "next-server", "npm", "npx", "pnpm", "yarn", "bun", "deno",
        "ruby", "java", "uvicorn", "gunicorn", "vite", "esbuild", "tsc",
    ]

    func detect(_ snapshot: ProcessSnapshot, cpuPercent: Double?) -> LeakReason? {
        let idle = cpuPercent.map { $0 < Thresholds.idleCpuPercent } ?? false
        if idle, isHoarding(snapshot) {
            return .hoardingSwappedMemory(footprint: snapshot.footprintBytes, resident: snapshot.residentBytes)
        }
        if snapshot.kind == .commandLine, let reason = commandLineLeak(snapshot, idle: idle) {
            return reason
        }
        if idle, snapshot.footprintBytes >= Thresholds.largeIdleFootprint,
           snapshot.age >= Thresholds.largeIdleMinAge {
            return .largeWhileIdle(footprint: snapshot.footprintBytes)
        }
        return nil
    }

    private func isHoarding(_ snapshot: ProcessSnapshot) -> Bool {
        guard snapshot.footprintBytes >= Thresholds.hoardingMinFootprint,
              snapshot.age >= Thresholds.hoardingMinAge else { return false }
        let resident = max(snapshot.residentBytes, 1)
        return Double(snapshot.footprintBytes) / Double(resident) >= Thresholds.hoardingSwappedRatio
    }

    private func commandLineLeak(_ snapshot: ProcessSnapshot, idle: Bool) -> LeakReason? {
        guard isDevRuntime(snapshot.name) else { return nil }
        if let cwd = snapshot.workingDirectory, !FileManager.default.fileExists(atPath: cwd) {
            return .workingDirectoryDeleted(path: cwd)
        }
        if idle, snapshot.age >= Thresholds.detachedMinAge, ancestry.isDetached(snapshot, isDevRuntime: { isDevRuntime($0.name) }) {
            return .detachedDevProcess(age: snapshot.age)
        }
        return nil
    }

    private func isDevRuntime(_ name: String) -> Bool {
        Self.devRuntimes.contains(name) || name.hasPrefix("python") || name.hasPrefix("Python")
    }
}
