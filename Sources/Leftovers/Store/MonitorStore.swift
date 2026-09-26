import Foundation

/// The app's single source of truth: refreshes every few seconds and
/// performs kills and protection changes on the user's behalf.
@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var report: MemoryReport?
    /// System totals, published before the (slower) process reading.
    @Published private(set) var system: SystemMemory?
    @Published private(set) var scanStats: ScanStats?
    @Published private(set) var protectedNames: Set<String>
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var busyIdentities: Set<ProcessIdentity> = []
    /// Which sidebar destination the dashboard shows; the menu can deep-link here.
    @Published var dashboardSection: DashboardSection = .leaks

    nonisolated private let engine = SampleEngine()
    private let terminator = ProcessTerminator()
    private let namesStore = ProtectedNamesStore()
    private var loop: Task<Void, Never>?
    private var hasReported = false
    private var hasReportedAgents = false
    /// Optional rewrite of each report before it is shown (snapshot redaction).
    var reportTransform: ((MemoryReport) -> MemoryReport)?

    init() {
        let names = namesStore.load()
        protectedNames = names
        // The first reading starts right now, in the background, not when the
        // main thread is next free.
        let first = startReading(protectedNames: names)
        loop = Task { [weak self] in
            await first.value
            while !Task.isCancelled {
                try? await Task.sleep(for: AppSettings.refreshInterval.duration)
                await self?.refresh()
            }
        }
    }

    deinit { loop?.cancel() }

    var suspects: [ClassifiedProcess] { visible.filter { $0.verdict.isSuspect } }
    var userProcesses: [ClassifiedProcess] { visible.filter { $0.verdict == .normal } }
    var protectedProcesses: [ClassifiedProcess] { visible.filter { !$0.verdict.isKillable } }
    var appGroups: [AppGroup] { AppGroup.group(report?.processes ?? []) }
    var reclaimableBytes: UInt64 { suspects.reduce(0) { $0 + $1.snapshot.footprintBytes } }

    private var visible: [ClassifiedProcess] {
        (report?.processes ?? []).filter { $0.snapshot.footprintBytes >= Thresholds.listMinFootprint }
    }

    /// Reads in three phases on a background task and publishes each as soon
    /// as it is ready: totals, then processes, then agents. The reading never
    /// waits for the main thread, so the first one runs in parallel with
    /// AppKit's launch. Later refreshes keep the previous agents on screen
    /// until the new ones are in (no flicker).
    func refresh() async {
        await startReading(protectedNames: protectedNames).value
    }

    nonisolated private func startReading(protectedNames: Set<String>) -> Task<Void, Never> {
        Task.detached(priority: .userInitiated) { [engine] in
            let system = await engine.readSystem()
            Task { @MainActor in self.publish(system: system) }
            let processes = await engine.readProcesses(protectedNames: protectedNames)
            Task { @MainActor in self.publish(system: system, processes: processes, agents: nil) }
            let agents = await engine.readAgents(processes.snapshots)
            await MainActor.run { self.publish(system: system, processes: processes, agents: agents) }
        }
    }

    private func publish(system: SystemMemory) {
        if self.system == nil { StartupTrace.mark("memory totals shown") }
        self.system = system
    }

    private func publish(system: SystemMemory, processes: ProcessReading, agents: AgentReading?) {
        let previous = report.flatMap { $0.agentsReady ? $0 : nil }
        let next = MemoryReport(system: system, processes: processes.processes,
                                agents: agents?.agents ?? previous?.agents ?? [],
                                duplicateToolServers: agents?.duplicates ?? previous?.duplicateToolServers ?? [],
                                takenAt: Date(), agentsReady: agents != nil || previous != nil)
        report = reportTransform?(next) ?? next
        if !hasReported { hasReported = true; StartupTrace.mark("processes shown") }
        guard let agents else { return }
        if !hasReportedAgents { hasReportedAgents = true; StartupTrace.mark("agents shown") }
        scanStats = ScanStats(processCount: processes.snapshots.count, processMilliseconds: processes.milliseconds,
                              agentCount: agents.agents.count, agentMilliseconds: agents.milliseconds)
    }

    func terminate(_ process: ClassifiedProcess) async {
        let result = await stop(process)
        lastActionMessage = "\(process.snapshot.name): \(result.message)"
        await refresh()
    }

    /// Stops every suspect concurrently, then refreshes once.
    func terminateAllSuspects() async {
        let targets = suspects
        let freed = targets.reduce(UInt64(0)) { $0 + $1.snapshot.footprintBytes }
        await withTaskGroup(of: TerminationResult.self) { group in
            for process in targets { group.addTask { await self.stop(process) } }
        }
        lastActionMessage = "Cleaned up \(targets.count) processes, about \(Format.bytes(freed))"
        await refresh()
    }

    private func stop(_ process: ClassifiedProcess) async -> TerminationResult {
        busyIdentities.insert(process.id)
        defer { busyIdentities.remove(process.id) }
        return await terminator.terminate(process)
    }

    func quitApp(_ group: AppGroup) async {
        lastActionMessage = await AppQuitter.quit(group)
        await refresh()
    }

    func quitAgent(_ session: AgentSession) async {
        let quitter = AgentSessionQuitter(policy: ProtectionPolicy(userProtectedNames: protectedNames))
        lastActionMessage = await quitter.quit(session)
        await refresh()
    }

    func toggleProtection(for name: String) {
        if protectedNames.contains(name) { protectedNames.remove(name) } else { protectedNames.insert(name) }
        namesStore.save(protectedNames)
        Task { await refresh() }
    }
}
