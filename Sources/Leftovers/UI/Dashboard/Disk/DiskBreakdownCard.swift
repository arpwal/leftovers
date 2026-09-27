import SwiftUI

/// One bar for the whole disk, with totals for the three owners: System
/// (macOS itself), Apps (the apps you installed and their data) and Yours.
struct DiskBreakdownCard: View {
    let breakdown: DiskBreakdown
    let isMeasuring: Bool

    var body: some View {
        UsageCard(title: "Disk", total: breakdown.volumes.containerTotal, segments: DiskArea.allCases.map {
            .init(label: label($0), bytes: breakdown.bytes($0), color: Self.color($0))
        }, caption: DiskOwner.allCases.map { "\($0.rawValue) \(Format.bytes(breakdown.bytes($0)))" }.joined(separator: "  ·  "))
    }

    private func label(_ area: DiskArea) -> String {
        let measuring = isMeasuring && (area == .apps || area == .appData || area == .other)
        return area.rawValue + (measuring ? " (measuring…)" : "")
    }

    /// Emerald marks app usage (what Leftovers can help with); grey is
    /// macOS and your files.
    static func color(_ area: DiskArea) -> Color {
        switch area {
        case .macOS: return .secondary.opacity(0.7)
        case .systemSupport: return .secondary.opacity(0.4)
        case .apps: return Palette.emerald600
        case .appData: return Palette.emerald500.opacity(0.55)
        case .other: return .secondary.opacity(0.2)
        case .free: return Color.primary.opacity(0.06)
        }
    }
}
