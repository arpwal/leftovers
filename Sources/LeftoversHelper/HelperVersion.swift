import Foundation

/// The build number (CFBundleVersion) of the app bundle this helper runs
/// from, read once at launch. After a Sparkle update a helper still running
/// from before reports the old build, and the app re-registers it.
enum HelperVersion {
    private struct InfoPlist: Decodable {
        let CFBundleVersion: String
    }

    static let current: String = {
        // Contents/MacOS/LeftoversHelper → Contents/Info.plist
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let plist = executable.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListDecoder().decode(InfoPlist.self, from: data) else { return "unknown" }
        return info.CFBundleVersion
    }()
}
