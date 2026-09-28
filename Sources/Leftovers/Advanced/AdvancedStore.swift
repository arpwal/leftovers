import Foundation

/// Data for the Advanced sections. Nothing is scanned until you open a
/// section; then the last report shows at once, a fresh scan replaces it,
/// and folder sizes fill in one by one (largest last-known first).
@MainActor
final class AdvancedStore: ObservableObject {
    static let shared = AdvancedStore()
    nonisolated static let maxAge: TimeInterval = 30 * 60
    @Published private(set) var reports: [AdvancedTool: ToolReport]
    @Published private(set) var scanning: Set<AdvancedTool> = []
    @Published private(set) var measuring: [AdvancedTool: (done: Int, total: Int)] = [:]
    @Published var lastActionMessage: String?
    private let cache: AdvancedCache

    init(cache: AdvancedCache = AdvancedCache()) {
        self.cache = cache
        reports = cache.load()
    }

    func isBusy(_ tool: AdvancedTool) -> Bool { scanning.contains(tool) || measuring[tool] != nil }

    func scanIfStale(_ tool: AdvancedTool, monitor: MonitorStore) async {
        if let report = reports[tool], Date().timeIntervalSince(report.scannedAt) < Self.maxAge { return }
        await scan(tool, monitor: monitor)
    }

    func scan(_ tool: AdvancedTool, monitor: MonitorStore) async {
        guard !isBusy(tool) else { return }
        scanning.insert(tool)
        let inUse = monitor.workingFolders
        var fresh = await Task.detached(priority: .userInitiated) { AdvancedScan.run(tool, inUse: inUse) }.value
        let old = Dictionary((reports[tool]?.items ?? []).map { ($0.id, $0.bytes) }, uniquingKeysWith: { a, _ in a })
        fresh.items = fresh.items.map { var item = $0; item.bytes = item.bytes ?? old[item.id] ?? nil; return item }
        reports[tool] = fresh
        scanning.remove(tool)
        await measure(tool)
        cache.save(reports)
    }

    private func measure(_ tool: AdvancedTool) async {
        let targets = (reports[tool]?.items ?? []).filter { $0.measurePath != nil }
            .sorted { ($0.bytes ?? .max) > ($1.bytes ?? .max) }
        guard !targets.isEmpty else { return }
        measuring[tool] = (0, targets.count)
        await withTaskGroup(of: (String, UInt64?).self) { group in
            var pending = targets[...]
            func next() { if let item = pending.popFirst(), let path = item.measurePath { group.addTask { (item.id, DiskSize.total(of: [path])) } } }
            for _ in 0..<4 { next() }
            for await (id, bytes) in group {
                if let bytes, let i = reports[tool]?.items.firstIndex(where: { $0.id == id }) { reports[tool]?.items[i].bytes = bytes }
                measuring[tool]?.done += 1
                next()
            }
        }
        measuring[tool] = nil
    }

    /// For `--snapshot --redact`: hide rows naming private folders (never saved).
    func hideForSnapshot(containing terms: [String]) {
        for tool in AdvancedTool.allCases {
            reports[tool]?.items.removeAll { item in
                terms.contains { item.title.localizedCaseInsensitiveContains($0) || item.detail.localizedCaseInsensitiveContains($0) }
            }
        }
    }

    func forget(_ ids: Set<String>, in tool: AdvancedTool) {
        reports[tool]?.items.removeAll { ids.contains($0.id) }
        cache.save(reports)
    }
}

/// Runs one tool's scanner off the main thread.
enum AdvancedScan {
    static func run(_ tool: AdvancedTool, inUse: [String: String]) -> ToolReport {
        switch tool {
        case .aiModels: return AIModelScanner.scan()
        case .docker: return DockerScanner.scan()
        case .nodeModules: return NodeModulesScanner.scan(inUse: inUse)
        case .simulators: return SimulatorScanner.scan()
        case .snapshots: return SnapshotScanner.scan()
        }
    }
}
