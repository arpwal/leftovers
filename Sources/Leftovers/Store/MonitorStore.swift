import Foundation

/// The app's single source of truth: refreshes every few seconds and
/// performs kills and protection changes on the user's behalf.
@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var report: MemoryReport?
    @Published private(set) var protectedNames: Set<String>
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var busyIdentities: Set<ProcessIdentity> = []
    /// Which sidebar destination the dashboard shows; the menu can deep-link here.
    @Published var dashboardSection: DashboardSection = .leaks

    private let engine = SampleEngine()
    private let terminator = ProcessTerminator()
    private let namesStore = ProtectedNamesStore()
    private var loop: Task<Void, Never>?
    /// Optional rewrite of each report before it is shown (snapshot redaction).
    var reportTransform: ((MemoryReport) -> MemoryReport)?

    init() {
        protectedNames = namesStore.load()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: AppSettings.refreshInterval.duration)
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

    func refresh() async {
        let sampled = await engine.sample(protectedNames: protectedNames)
        report = reportTransform?(sampled) ?? sampled
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
