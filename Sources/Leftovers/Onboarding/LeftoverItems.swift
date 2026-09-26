import SwiftUI

/// The three things kids leave around the house, standing in for what agents
/// leave running. Flat, single-weight glyphs so they read at a glance.
enum LeftoverItem: Int, CaseIterable, Identifiable {
    case blocks, food, shoes

    var id: Int { rawValue }

    /// What each one stands for on a Mac.
    var caption: String {
        switch self {
        case .blocks: return "dev server · 1.2 GB"
        case .food: return "MCP server · 380 MB"
        case .shoes: return "build · 2.1 GB"
        }
    }

    @ViewBuilder var glyph: some View {
        switch self {
        case .blocks: BuildingBlock()
        case .food: Image(systemName: "takeoutbag.and.cup.and.straw.fill").font(.system(size: 50))
        case .shoes: Image(systemName: "shoe.2.fill").font(.system(size: 46))
        }
    }
}

/// A toy building block seen from the front: a brick with two studs.
private struct BuildingBlock: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                stud
                stud
            }
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .frame(width: 64, height: 36)
                .overlay(alignment: .top) {
                    // A lighter top edge gives the flat brick a little depth.
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.white.opacity(0.25)).frame(height: 8)
                }
        }
    }

    private var stud: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous).frame(width: 18, height: 8)
    }
}
