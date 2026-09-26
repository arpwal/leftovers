import SwiftUI

/// Four headline numbers across the top of every section.
struct StatCards: View {
    let system: SystemMemory
    let reclaimableBytes: UInt64

    /// Four across when they fit, otherwise two by two; never wider than
    /// the window, and never a lone card on its own row.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { pressure; swap; compressed; reclaimable }
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow { pressure; swap }
                GridRow { compressed; reclaimable }
            }
        }
    }

    private var pressure: some View {
        card("Pressure") {
            HStack(spacing: 8) {
                Circle().fill(Palette.color(for: system.pressure)).frame(width: 10, height: 10)
                Text(system.pressure.label)
            }
        } footer: { Text("\(system.availablePercent)% available") }
    }

    private var swap: some View {
        card("Swap") { Text(Format.bytes(system.swapUsedBytes)) }
            footer: { SwapBar(fraction: system.swapFraction, total: system.swapTotalBytes) }
    }

    private var compressed: some View {
        card("Compressed") { Text(Format.bytes(system.compressedBytes)) }
            footer: { Text("of \(Format.bytes(system.totalBytes)) RAM") }
    }

    private var reclaimable: some View {
        card("Reclaimable") { Text(Format.bytes(reclaimableBytes)) }
            footer: { Text(reclaimableBytes == 0 ? "Nothing to clean up" : "From likely leaks") }
    }

    private func card<Value: View, Footer: View>(_ title: String, @ViewBuilder value: () -> Value,
                                                 @ViewBuilder footer: () -> Footer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption2.weight(.medium)).kerning(0.6).foregroundStyle(.secondary)
            value().font(.system(size: 20, weight: .semibold)).monospacedDigit()
            footer().font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator.opacity(0.6)))
    }
}

/// Thin capsule showing how full swap is.
private struct SwapBar: View {
    let fraction: Double
    let total: UInt64

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Palette.swapTint(fraction: fraction))
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 5)
            Text("of \(Format.bytes(total))").fixedSize()
        }
    }
}
