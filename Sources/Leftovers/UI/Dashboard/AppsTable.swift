import SwiftUI

/// One row per app, with its real logo, all helpers summed.
struct AppsTable: View {
    let groups: [AppGroup]
    let totalBytes: UInt64

    var body: some View {
        Table(groups) {
            TableColumn("App") { group in
                HStack(spacing: 10) {
                    Image(nsImage: AppIconProvider.icon(atPath: group.bundlePath))
                        .resizable().interpolation(.high).frame(width: 24, height: 24)
                    Text(group.name).fontWeight(.medium)
                }
            }
            .width(min: 200, ideal: 260)
            TableColumn("Memory") { group in
                Text(Format.bytes(group.totalFootprint)).monospacedDigit()
            }
            .width(90)
            TableColumn("Share of RAM") { group in
                ShareBar(fraction: totalBytes == 0 ? 0 : Double(group.totalFootprint) / Double(totalBytes))
            }
            .width(min: 120, ideal: 180)
            TableColumn("Processes") { Text("\($0.processes.count)").monospacedDigit() }
                .width(80)
            TableColumn("CPU") { Text(Format.cpu($0.totalCPU)).monospacedDigit() }
                .width(60)
        }
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
