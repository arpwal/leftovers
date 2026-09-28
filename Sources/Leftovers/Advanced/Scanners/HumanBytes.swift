import Foundation

/// Parses sizes the way Docker prints them: "1.2GB", "512.3kB", "0B".
enum HumanBytes {
    static func parse(_ text: String) -> UInt64? {
        let trimmed = text.split(separator: " ").first.map(String.init) ?? text
        let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("KB", 1e3), ("B", 1)]
        for (suffix, scale) in units where trimmed.hasSuffix(suffix) {
            guard let value = Double(trimmed.dropLast(suffix.count)) else { return nil }
            return UInt64(value * scale)
        }
        return nil
    }
}
