import Darwin
import Foundation

/// The build number (CFBundleVersion) of the app bundle this helper runs
/// from. `current` is read once at launch; `onDisk` re-reads the bundle.
/// After a Sparkle update the two differ, and the helper exits so launchd
/// starts the new binary on the next request. The app never unregisters the
/// helper for an update: unregistering would withdraw the user's Login Items
/// approval. (2026-11-23: replaces app-side re-registration.)
enum HelperVersion {
    private struct InfoPlist: Decodable {
        let CFBundleVersion: String
    }

    static let current: String = read() ?? "unknown"

    /// The build now installed at this helper's bundle path; nil if unreadable.
    static var onDisk: String? { read() }

    /// True once the bundle on disk is a different build than the one running.
    static var isStale: Bool {
        guard let installed = onDisk, current != "unknown" else { return false }
        return installed != current
    }

    /// Contents/MacOS/LeftoversHelper → Contents/Info.plist. Uses the kernel's
    /// path for this process, not argv[0], which launchd needn't make absolute.
    private static func read() -> String? {
        guard let executable = executablePath() else { return nil }
        let plist = URL(fileURLWithPath: executable).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListDecoder().decode(InfoPlist.self, from: data) else { return nil }
        return info.CFBundleVersion
    }

    private static func executablePath() -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(getpid(), &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
