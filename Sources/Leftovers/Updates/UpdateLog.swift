import Foundation

/// Appends updater failures to ~/Library/Logs/Leftovers/updates.log (visible
/// in Console.app), so a failed update can be diagnosed afterwards.
enum UpdateLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Leftovers/updates.log")

    static func record(_ message: String) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let line = "\(ISO8601DateFormatter().string(from: Date())) [\(version) at \(Bundle.main.bundlePath)] \(message)\n"
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(Data(line.utf8)); try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
