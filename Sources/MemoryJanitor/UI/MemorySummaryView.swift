import SwiftUI

/// Machine-wide numbers: pressure, swap, compressed, and what can be reclaimed.
struct MemorySummaryView: View {
    let system: SystemMemory
    let reclaimableBytes: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pressure: \(system.pressure.label)", systemImage: "gauge.with.dots.needle.33percent")
                    .foregroundStyle(pressureColor)
                Spacer()
                Text("\(system.availablePercent)% available").foregroundStyle(.secondary)
            }
            .font(.headline)
            ProgressView(value: system.swapFraction) {
                Text("Swap \(Format.bytes(system.swapUsedBytes)) of \(Format.bytes(system.swapTotalBytes))")
                    .font(.caption)
            }
            .tint(Palette.swapTint(fraction: system.swapFraction))
            HStack {
                stat("RAM", Format.bytes(system.totalBytes))
                stat("Compressed", Format.bytes(system.compressedBytes))
                stat("Reclaimable", Format.bytes(reclaimableBytes))
            }
        }
    }

    private var pressureColor: Color { Palette.color(for: system.pressure) }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
