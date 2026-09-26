import SwiftUI

/// The top of the menu: the one custom piece in an otherwise standard menu.
/// Memory pressure plus two progress bars (memory in use, swap).
struct MenuHeaderView: View {
    @ObservedObject var store: MonitorStore
    static let width: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let system = store.system {
                HStack {
                    Text("Memory").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Circle().fill(Palette.color(for: system.pressure)).frame(width: 7, height: 7)
                    Text("Pressure \(system.pressure.label.lowercased())").foregroundStyle(.secondary)
                }
                meter("In use", detail: "\(100 - system.availablePercent)%",
                      fraction: Double(100 - system.availablePercent) / 100, tint: Palette.color(for: system.pressure))
                meter("Swap", detail: "\(Format.bytes(system.swapUsedBytes)) of \(Format.bytes(system.swapTotalBytes))",
                      fraction: system.swapFraction, tint: Palette.swapTint(fraction: system.swapFraction))
                HStack {
                    Text("Compressed \(Format.bytes(system.compressedBytes))")
                    Spacer()
                    Text("Reclaimable \(Format.bytes(store.reclaimableBytes))")
                }
                .foregroundStyle(.secondary)
                ScanSpeedLabel(stats: store.scanStats).foregroundStyle(.tertiary)
            } else {
                Text("Reading memory…").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .monospacedDigit()
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(width: Self.width, alignment: .leading)
    }

    private func meter(_ title: String, detail: String, fraction: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(detail).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(tint).frame(width: max(4, proxy.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: 6)
        }
    }
}
