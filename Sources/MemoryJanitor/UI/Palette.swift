import SwiftUI

/// Rainbow Labs design system: zinc neutrals, emerald as the ONLY accent.
/// State language: emerald = healthy/done, amber = needs attention, red = critical.
/// Never introduce another hue to carry a distinction.
enum Palette {
    static let emerald500 = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let emerald600 = Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255)
    static let amber500 = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let red500 = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)

    static func color(for pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return emerald600
        case .warning: return amber500
        case .critical: return red500
        }
    }

    /// Swap fill: emerald until it is nearly full.
    static func swapTint(fraction: Double) -> Color {
        fraction > 0.9 ? red500 : (fraction > 0.75 ? amber500 : emerald500)
    }
}
