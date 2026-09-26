import Foundation

/// One complete reading of the machine.
struct MemoryReport {
    let system: SystemMemory
    let processes: [ClassifiedProcess]
    let agents: [AgentSession]
    let duplicateToolServers: [DuplicatedToolServer]
    let takenAt: Date
}

/// Owns the stateful parts of sampling (CPU deltas) off the main thread.
actor SampleEngine {
    private let processSampler = ProcessSampler()
    private let systemSampler = SystemMemorySampler()
    private var cpuTracker = CpuTracker()

    func sample(protectedNames: Set<String>) -> MemoryReport {
        let now = Date()
        let snapshots = processSampler.sample()
        let cpu = cpuTracker.update(with: snapshots, at: now)
        let classifier = ProcessClassifier(policy: ProtectionPolicy(userProtectedNames: protectedNames))
        let processes = classifier.classify(snapshots, cpu: cpu)
            .sorted { $0.snapshot.footprintBytes > $1.snapshot.footprintBytes }
        let agents = AgentSessionBuilder(snapshots).sessions()
        return MemoryReport(
            system: systemSampler.sample(),
            processes: processes,
            agents: agents,
            duplicateToolServers: DuplicateToolServerFinder.find(in: agents),
            takenAt: now
        )
    }
}
