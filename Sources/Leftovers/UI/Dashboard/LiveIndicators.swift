import SwiftUI

/// "Updated 4 s ago" with a pulsing dot while work is in flight: shows the
/// data is live without anyone having to ask.
struct UpdatedAgo: View {
    let date: Date?
    var isWorking = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 6) {
                Circle().fill(isWorking ? Palette.emerald500 : Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .opacity(isWorking ? (Int(context.date.timeIntervalSince1970 * 2) % 2 == 0 ? 1 : 0.35) : 1)
                    .animation(.easeInOut(duration: 0.5), value: context.date)
                Text(label(now: context.date)).monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func label(now: Date) -> String {
        guard let date else { return isWorking ? "Loading…" : "Not loaded yet" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "Updated \(seconds) s ago" }
        return "Updated \(date.formatted(.relative(presentation: .named)))"
    }
}

/// One live counter in an activity strip: a spinner while running, a check when done.
struct ActivityPill: View {
    let text: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 5) {
            if isDone {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.emerald500)
            } else {
                ProgressView().controlSize(.mini)
            }
            Text(text).monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .animation(.easeOut(duration: 0.2), value: isDone)
    }
}

/// Placeholder rows that shimmer while the first data loads.
struct SkeletonRows: View {
    var count = 8
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 12) {
                    bar(width: 180 - CGFloat(index % 3) * 30)
                    Spacer()
                    bar(width: 120)
                    bar(width: 70)
                    bar(width: 50)
                }
            }
        }
        .padding(.vertical, 8)
        .mask(LinearGradient(colors: [.black.opacity(0.35), .black, .black.opacity(0.35)],
                             startPoint: UnitPoint(x: phase, y: 0), endPoint: UnitPoint(x: phase + 1, y: 0)))
        .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 } }
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: width, height: 12)
    }
}
