import SwiftUI

/// A small isometric table, shaded like a 3D object with three face tones.
/// Uses `primary` opacities so it reads correctly in light and dark mode.
struct IsometricTable: View {
    static let width: CGFloat = 112
    static let topHeight: CGFloat = 56
    private static let thickness: CGFloat = 7
    private static let legHeight: CGFloat = 30

    var body: some View {
        Canvas { context, _ in
            let w = Self.width, h = Self.topHeight, t = Self.thickness
            drawLegs(&context, w: w, h: h, t: t)
            context.fill(face([(0, h / 2), (w / 2, h), (w / 2, h + t), (0, h / 2 + t)]), with: .color(.primary.opacity(0.16)))
            context.fill(face([(w / 2, h), (w, h / 2), (w, h / 2 + t), (w / 2, h + t)]), with: .color(.primary.opacity(0.26)))
            context.fill(face([(0, h / 2), (w / 2, 0), (w, h / 2), (w / 2, h)]), with: .color(.primary.opacity(0.07)))
            context.stroke(face([(0, h / 2), (w / 2, 0), (w, h / 2), (w / 2, h)]), with: .color(.primary.opacity(0.12)), lineWidth: 0.8)
        }
        .frame(width: Self.width, height: Self.topHeight + Self.thickness + Self.legHeight)
    }

    private func drawLegs(_ context: inout GraphicsContext, w: CGFloat, h: CGFloat, t: CGFloat) {
        for (x, y) in [(6.0, h / 2), (w / 2, h - 3), (w - 6, h / 2)] {
            let leg = Path(roundedRect: CGRect(x: x - 2, y: y + t - 2, width: 4, height: Self.legHeight), cornerRadius: 2)
            context.fill(leg, with: .color(.primary.opacity(0.22)))
        }
    }

    private func face(_ points: [(CGFloat, CGFloat)]) -> Path {
        Path { path in
            path.move(to: CGPoint(x: points[0].0, y: points[0].1))
            points.dropFirst().forEach { path.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
            path.closeSubpath()
        }
    }
}

/// What an agent leaves on the table: a plate, a mug, some crumbs.
struct TableMess: View {
    var body: some View {
        ZStack {
            Ellipse().fill(.background).overlay(Ellipse().stroke(.primary.opacity(0.25), lineWidth: 1))
                .frame(width: 30, height: 14).offset(x: -14, y: 2)
            Ellipse().fill(.primary.opacity(0.10)).frame(width: 16, height: 6).offset(x: -14, y: 2)
            mug.offset(x: 18, y: -6)
            ForEach(0..<4, id: \.self) { index in
                Circle().fill(.primary.opacity(0.3)).frame(width: 3, height: 3)
                    .offset(x: CGFloat(index * 7 - 4), y: CGFloat(10 + (index % 2) * 3))
            }
        }
    }

    private var mug: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3).fill(.primary.opacity(0.35)).frame(width: 11, height: 13)
            Ellipse().fill(.primary.opacity(0.55)).frame(width: 11, height: 4)
        }
    }
}

/// A coding agent: a small glass orb with a sparkle.
struct AgentOrb: View {
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Palette.emerald500.opacity(0.95), Palette.emerald600],
                                         startPoint: .top, endPoint: .bottom))
            Circle().fill(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center))
                .padding(3)
            Image(systemName: "sparkle").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
        }
        .frame(width: 26, height: 26)
        .shadow(color: Palette.emerald600.opacity(0.35), radius: 6, y: 3)
    }
}
