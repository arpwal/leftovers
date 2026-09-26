import SwiftUI

/// One animated illustration per page. Each settles into a still frame and
/// respects Reduce Motion.
struct OnboardingIllustration: View {
    let page: OnboardingPage

    var body: some View {
        switch page {
        case .hiddenLeaks: FootprintIllustration()
        case .agentLeftovers: LeftoversIllustration()
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
