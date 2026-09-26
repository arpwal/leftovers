import Foundation

/// One complete reading of the machine. `agentsReady` is false while the
/// agent phase of the very first reading is still running.
struct MemoryReport {
    let system: SystemMemory
    let processes: [ClassifiedProcess]
    let agents: [AgentSession]
    let duplicateToolServers: [DuplicatedToolServer]
    let takenAt: Date
    var agentsReady: Bool = true
}

/// Result of the process phase; the snapshots feed the agent phase.
struct ProcessReading {
    let snapshots: [ProcessSnapshot]
    let processes: [ClassifiedProcess]
    let milliseconds: Int
}

/// Result of the agent phase.
struct AgentReading {
    let agents: [AgentSession]
    let duplicates: [DuplicatedToolServer]
    let milliseconds: Int
}

/// Reads memory in three phases, fastest first, so the UI can show each as
/// soon as it is ready: system totals (sysctl, ~1 ms), processes (libproc),
/// then agent sessions (argv of every agent's descendants). Runs off the main
/// thread and owns the stateful part (CPU deltas).
actor SampleEngine {
    private let processSampler = ProcessSampler()
    private let systemSampler = SystemMemorySampler()
    private var cpuTracker = CpuTracker()

    func readSystem() -> SystemMemory {
        systemSampler.sample()
    }

    func readProcesses(protectedNames: Set<String>) -> ProcessReading {
        let start = Date()
        let snapshots = processSampler.sample()
        let cpu = cpuTracker.update(with: snapshots, at: start)
        let classifier = ProcessClassifier(policy: ProtectionPolicy(userProtectedNames: protectedNames))
        let processes = classifier.classify(snapshots, cpu: cpu)
            .sorted { $0.snapshot.footprintBytes > $1.snapshot.footprintBytes }
        return ProcessReading(snapshots: snapshots, processes: processes, milliseconds: Self.elapsed(since: start))
    }

    func readAgents(_ snapshots: [ProcessSnapshot]) -> AgentReading {
        let start = Date()
        let agents = AgentSessionBuilder(snapshots).sessions()
        return AgentReading(agents: agents, duplicates: DuplicateToolServerFinder.find(in: agents),
                            milliseconds: Self.elapsed(since: start))
    }

    /// All three phases at once, for the command line.
    func sample(protectedNames: Set<String>) -> MemoryReport {
        let system = readSystem()
        let processes = readProcesses(protectedNames: protectedNames)
        let agents = readAgents(processes.snapshots)
        return MemoryReport(system: system, processes: processes.processes, agents: agents.agents,
                            duplicateToolServers: agents.duplicates, takenAt: Date())
    }

    private static func elapsed(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
