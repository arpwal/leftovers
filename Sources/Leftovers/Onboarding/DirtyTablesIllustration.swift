import SwiftUI

/// "Agents leave a mess behind": on each table an agent drops in, works
/// (dishes appear), then drifts off and leaves the dishes. Staggered across
/// three tables, it runs once and settles on three messy tables.
struct DirtyTablesIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phases: [TablePhase] = Array(repeating: .empty, count: 3)
    private static let leftovers = ["dev server · 1.2 GB", "MCP server · 380 MB", "build · 2.1 GB"]

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            ForEach(0..<3, id: \.self) { index in
                table(index: index)
            }
        }
        .task { await play() }
    }

    private func table(index: Int) -> some View {
        let phase = phases[index]
        return VStack(spacing: 8) {
            ZStack(alignment: .top) {
                IsometricTable()
                TableMess()
                    .offset(y: 16)
                    .opacity(phase >= .working ? 1 : 0)
                    .scaleEffect(phase >= .working ? 1 : 0.6)
                AgentOrb()
                    .offset(y: phase == .empty ? -70 : (phase == .left ? -86 : -14))
                    .opacity(phase == .arriving || phase == .working ? 1 : 0)
            }
            Text(Self.leftovers[index])
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(phase == .left ? 1 : 0)
        }
    }

    private func play() async {
        if reduceMotion { phases = Array(repeating: .left, count: 3); return }
        for index in phases.indices {
            try? await Task.sleep(for: .milliseconds(index == 0 ? 250 : 120))
            await advance(index, to: .arriving, after: 0, animation: .spring(duration: 0.45, bounce: 0.35))
            await advance(index, to: .working, after: 420, animation: .spring(duration: 0.4))
            await advance(index, to: .left, after: 520, animation: .easeIn(duration: 0.45))
        }
    }

    private func advance(_ index: Int, to phase: TablePhase, after milliseconds: Int, animation: Animation) async {
        if milliseconds > 0 { try? await Task.sleep(for: .milliseconds(milliseconds)) }
        withAnimation(animation) { phases[index] = phase }
    }
}

/// Where one table is in its little story.
enum TablePhase: Int, Comparable {
    case empty, arriving, working, left
    static func < (a: TablePhase, b: TablePhase) -> Bool { a.rawValue < b.rawValue }
}
