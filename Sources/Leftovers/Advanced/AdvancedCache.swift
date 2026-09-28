import Foundation

/// Each Advanced tool's last report, saved so a section opens with its last
/// numbers while it re-scans.
struct AdvancedCache {
    var url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Leftovers/advanced-cache.json")

    func load() -> [AdvancedTool: ToolReport] {
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([String: ToolReport].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: saved.compactMap { key, report in AdvancedTool(rawValue: key).map { ($0, report) } })
    }

    func save(_ reports: [AdvancedTool: ToolReport]) {
        let keyed = Dictionary(uniqueKeysWithValues: reports.map { ($0.key.rawValue, $0.value) })
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(keyed).write(to: url, options: .atomic)
    }
}
