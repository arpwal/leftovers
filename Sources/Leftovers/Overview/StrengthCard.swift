import SwiftUI

/// Strength now vs after a safe cleanup, with the formula one click away.
struct StrengthCard: View {
    let model: OverviewModel
    @State private var showsFormula = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Mac's strength").font(.headline)
                Spacer()
                Button("How is this calculated?") { showsFormula.toggle() }
                    .buttonStyle(.link).font(.caption)
                    .popover(isPresented: $showsFormula) { formula.padding(16).frame(width: 340) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(model.now)%").font(.system(size: 44, weight: .bold)).monospacedDigit()
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                Text("\(model.after)%").font(.system(size: 44, weight: .bold)).monospacedDigit()
                    .foregroundStyle(Palette.emerald600)
                Text("after cleanup").foregroundStyle(.secondary)
            }
            bar(label: "Now", value: model.now, tint: Palette.amber500)
            bar(label: "After cleanup", value: model.after, tint: Palette.emerald500)
            Text(sentence).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sentence: String {
        if model.after <= model.now { return "Nothing left behind is slowing your Mac right now." }
        return "Leftovers are holding \(Format.bytes(model.leakBytes)) of memory and \(Format.bytes(model.inputs.reclaimableDisk)) of disk."
    }

    private func bar(label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(tint).frame(width: proxy.size.width * CGFloat(value) / 100)
                        .animation(.easeOut(duration: 0.6), value: value)
                }
            }
            .frame(height: 8)
        }
    }

    private var formula: some View {
        let parts = SystemStrength.parts(model.inputs)
        return VStack(alignment: .leading, spacing: 8) {
            Text("An estimate, not a benchmark").font(.headline)
            Text("• 50% memory: how much RAM is available (now \(pct(parts.memory)))")
            Text("• 30% swap: swap is what makes a Mac feel slow; it counts fully against you at a quarter of your RAM (now \(pct(parts.swap)))")
            Text("• 20% disk: fully good at 20% free (now \(pct(parts.disk)))")
            Text("\"After cleanup\" is the same formula once likely leaks are quit and safe-to-remove worktrees are removed. It only counts what Leftovers can clean safely.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pct(_ value: Double) -> String { "\(Int(value * 100 + 0.5))%" }
}
