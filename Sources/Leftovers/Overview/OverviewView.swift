import SwiftUI

/// "How much of your Mac's strength are leftovers using?" — the first thing
/// you see: strength now vs after a safe cleanup, memory and disk, and what's
/// holding it back, each linking to where you can fix it.
struct OverviewView: View {
    @ObservedObject var store: MonitorStore
    @ObservedObject var worktrees: WorktreeStore
    @ObservedObject var jobs: ScheduledStore
    @ObservedObject var caches: DiskStore
    @State private var disk = DiskUsage.read()

    var body: some View {
        if let model = OverviewModel.make(store: store, worktrees: worktrees, jobs: jobs, caches: caches, disk: disk) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    StrengthCard(model: model)
                    HStack(alignment: .top, spacing: 14) {
                        UsageCard(title: "Memory", total: model.inputs.totalMemory, segments: [
                            .init(label: "In use", bytes: inUse(model), color: .secondary.opacity(0.45)),
                            .init(label: "Held by leftovers", bytes: model.leakBytes, color: Palette.amber500),
                            .init(label: "Available", bytes: model.inputs.availableMemory, color: Palette.emerald500.opacity(0.35)),
                        ])
                        UsageCard(title: "Disk", total: model.inputs.diskTotal, segments: [
                            .init(label: "Used", bytes: diskUsed(model), color: .secondary.opacity(0.45)),
                            .init(label: model.worktreesMeasured ? "Removable worktrees" : "Worktrees (measuring…)",
                                  bytes: model.worktreeBytes, color: Palette.amber500),
                            .init(label: model.cachesMeasured ? "Developer caches" : "Developer caches (measuring…)",
                                  bytes: model.cacheBytes, color: Palette.amber500.opacity(0.6)),
                            .init(label: "Free", bytes: model.inputs.diskFree, color: Palette.emerald500.opacity(0.35)),
                        ])
                    }
                    HoldingBackList(model: model) { store.dashboardSection = $0 }
                }
            }
        } else {
            SkeletonRows()
        }
    }

    private func inUse(_ m: OverviewModel) -> UInt64 {
        let used = m.inputs.totalMemory > m.inputs.availableMemory ? m.inputs.totalMemory - m.inputs.availableMemory : 0
        return used > m.leakBytes ? used - m.leakBytes : 0
    }

    private func diskUsed(_ m: OverviewModel) -> UInt64 {
        let used = m.inputs.diskTotal > m.inputs.diskFree ? m.inputs.diskTotal - m.inputs.diskFree : 0
        let removable = m.worktreeBytes + m.cacheBytes
        return used > removable ? used - removable : 0
    }
}
