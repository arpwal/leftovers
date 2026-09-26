import SwiftUI

/// One row per app, with its real logo, all helpers summed, and a Quit
/// button for apps it is safe to quit. Columns shrink to fit; no sideways scroll.
struct AppsTable: View {
    let groups: [AppGroup]
    let totalBytes: UInt64
    @ObservedObject var store: MonitorStore

    var body: some View {
        Table(groups) {
            TableColumn("App") { group in
                HStack(spacing: 10) {
                    Image(nsImage: AppIconProvider.icon(atPath: group.bundlePath))
                        .resizable().interpolation(.high).frame(width: 22, height: 22)
                    Text(group.name).fontWeight(.medium).lineLimit(1)
                }
            }
            .width(min: 120, ideal: 220)
            TableColumn("Memory") { Text(Format.bytes($0.totalFootprint)).monospacedDigit() }
                .width(min: 64, ideal: 84)
            TableColumn("Share of RAM") { group in
                ShareBar(fraction: totalBytes == 0 ? 0 : Double(group.totalFootprint) / Double(totalBytes))
            }
            .width(min: 50, ideal: 140)
            TableColumn("Processes") { Text("\($0.processes.count)").monospacedDigit() }
                .width(min: 40, ideal: 70)
            TableColumn("CPU") { Text(Format.cpu($0.totalCPU)).monospacedDigit() }
                .width(min: 40, ideal: 56)
            TableColumn("") { group in
                if canQuit(group) { Button("Quit") { quit(group) }.controlSize(.small) }
            }
            .width(min: 50, ideal: 56)
        }
        .contextMenu(forSelectionType: AppGroup.ID.self) { ids in
            if let group = groups.first(where: { ids.contains($0.id) }), canQuit(group) {
                Button("Quit \(group.name)…") { quit(group) }
            }
        }
    }

    private func canQuit(_ group: AppGroup) -> Bool {
        AppQuitter.canQuit(group, protectedNames: store.protectedNames)
    }

    private func quit(_ group: AppGroup) {
        guard Confirm.quitApp(group) else { return }
        Task { await store.quitApp(group) }
    }
}

/// Proportional bar for a row's share of total memory.
private struct ShareBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(Palette.emerald500.opacity(0.85))
                    .frame(width: max(3, proxy.size.width * min(fraction, 1)))
            }
        }
        .frame(height: 6)
    }
}
