import Foundation

/// Human-readable formatting shared by models and views.
enum Format {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowsNonnumericFormatting = false // "0 bytes", never "Zero KB"
        return formatter
    }()

    static func bytes(_ value: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(clamping: value))
    }

    /// "9d 11h", "3h 12m", "45m".
    static func age(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let days = total / 86_400, hours = (total % 86_400) / 3_600, minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static func cpu(_ percent: Double?) -> String {
        guard let percent else { return "…" }
        return String(format: "%.1f%%", percent)
    }
}
