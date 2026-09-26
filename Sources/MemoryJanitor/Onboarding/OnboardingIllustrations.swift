import SwiftUI

/// One animated illustration per page. Each settles into a still frame and
/// respects Reduce Motion.
struct OnboardingIllustration: View {
    let page: OnboardingPage

    var body: some View {
        switch page {
        case .hiddenLeaks: FootprintIllustration()
        case .agentLeftovers: AgentTilesIllustration()
        case .brand: BrandIllustration()
        }
    }
}

/// "7 MB in RAM" stays tiny while "59 GB footprint" keeps growing.
private struct FootprintIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            bar(label: "In RAM", value: "7 MB", fraction: 0.03, tint: .secondary.opacity(0.5))
            bar(label: "Footprint", value: "59 GB", fraction: grown ? 1 : 0.05, tint: Palette.emerald500)
        }
        .frame(width: 320)
        .onAppear {
            if reduceMotion { grown = true } else {
                withAnimation(.easeInOut(duration: 1.6).delay(0.3)) { grown = true }
            }
        }
    }

    private func bar(label: String, value: String, fraction: CGFloat, tint: some ShapeStyle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).monospacedDigit().fontWeight(.semibold)
            }
            .font(.callout)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(tint).frame(width: max(8, proxy.size.width * fraction))
                }
            }
            .frame(height: 14)
        }
    }
}

/// Copies of the same tool server appearing one after another.
private struct AgentTilesIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = 0
    private static let columns = 5, rows = 3

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(0..<Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        tile(index: row * Self.columns + column)
                    }
                }
            }
        }
        .task {
            let total = Self.columns * Self.rows
            if reduceMotion { visible = total; return }
            for step in 1...total {
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.spring(duration: 0.35)) { visible = step }
            }
        }
    }

    private func tile(index: Int) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.emerald500.opacity(index == 0 ? 0.9 : 0.25 + 0.03 * Double(index % 5)))
            .overlay(Image(systemName: "sparkle").foregroundStyle(.white.opacity(0.9)))
            .frame(width: 48, height: 48)
            .scaleEffect(index < visible ? 1 : 0.4)
            .opacity(index < visible ? 1 : 0)
    }
}

/// The app icon, floating gently.
private struct BrandIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage ?? NSImage())
            .resizable()
            .interpolation(.high)
            .frame(width: 168, height: 168)
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            .offset(y: floating ? -6 : 6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { floating = true }
            }
    }
}
