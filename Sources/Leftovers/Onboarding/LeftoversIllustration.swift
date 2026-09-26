import SwiftUI

/// "Agents leave a mess behind": blocks, food and shoes drop onto the floor
/// one after another, each labelled with what it stands for. Runs once and
/// settles; respects Reduce Motion.
struct LeftoversIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = 0

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            ForEach(LeftoverItem.allCases) { item in
                spot(item, isLanded: item.rawValue < landed)
            }
        }
        .task { await play() }
    }

    private func spot(_ item: LeftoverItem, isLanded: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
                    .frame(width: 112, height: 112)
                Ellipse()
                    .fill(.primary.opacity(isLanded ? 0.12 : 0.03))
                    .frame(width: isLanded ? 64 : 24, height: 8)
                    .padding(.bottom, 20)
                item.glyph
                    .foregroundStyle(Palette.emerald500.gradient)
                    .rotationEffect(.degrees(isLanded ? 0 : (item == .food ? 14 : -14)))
                    .offset(y: isLanded ? -26 : -120)
                    .opacity(isLanded ? 1 : 0)
            }
            .frame(width: 112, height: 112)
            Text(item.caption)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(isLanded ? 1 : 0)
        }
    }

    private func play() async {
        let total = LeftoverItem.allCases.count
        if reduceMotion { landed = total; return }
        for step in 1...total {
            try? await Task.sleep(for: .milliseconds(step == 1 ? 350 : 550))
            withAnimation(.spring(duration: 0.55, bounce: 0.4)) { landed = step }
        }
    }
}
