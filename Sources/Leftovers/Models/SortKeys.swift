import Foundation

// Comparable keys for sortable table columns. Optionals map to a value that
// sorts last, so a "…" never jumps to the top.

extension ClassifiedProcess {
    var sortName: String { snapshot.name.lowercased() }
    var sortMemory: UInt64 { snapshot.footprintBytes }
    var sortRAM: UInt64 { snapshot.residentBytes }
    var sortCPU: Double { cpuPercent ?? -1 }
    var sortStarted: Date { snapshot.startDate }
}

extension AppGroup {
    var sortName: String { name.lowercased() }
    var processCount: Int { processes.count }
}

extension AgentSession {
    var sortAgent: String { kind.rawValue }
    var sortProject: String { project.lowercased() }
    var memberCount: Int { members.count }
    var toolServerCount: Int { toolServers.count }
    var sortStarted: Date { root.startDate }
}

extension ScheduledJob {
    var sortTitle: String { title.lowercased() }
    var sortNextRun: Date { JobScheduleText.nextRun(schedule, lastRun: lastActivity) ?? .distantFuture }
    /// Failed first, then running, waiting, off.
    var sortStatus: Int { !isLoaded ? 3 : hasFailed ? 0 : isRunning ? 1 : 2 }
}
