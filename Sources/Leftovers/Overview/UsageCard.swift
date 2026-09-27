import SwiftUI

/// A stacked bar for memory or disk: what's used, what leftovers hold, what's free.
struct UsageCard: View {
    struct Segment: Identifiable {
        let label: String
        let bytes: UInt64
        let color: Color
        var id: String { label }
    }

    let title: String
    let total: UInt64
    let segments: [Segment]
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                if let caption { Text(caption).font(.callout).monospacedDigit().foregroundStyle(.secondary).lineLimit(1) }
                Spacer()
                Text(Format.bytes(total)).foregroundStyle(.secondary).monospacedDigit()
            }
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(segments) { segment in
                        Rectangle().fill(segment.color)
                            .frame(width: max(0, proxy.size.width * share(segment.bytes) - 2))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(segments) { segment in
                    HStack(spacing: 6) {
                        Circle().fill(segment.color).frame(width: 8, height: 8)
                        Text(segment.label)
                        Spacer()
                        Text(Format.bytes(segment.bytes)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func share(_ bytes: UInt64) -> CGFloat {
        total == 0 ? 0 : CGFloat(Double(bytes) / Double(total))
    }
}
