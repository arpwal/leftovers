import LeftoversHelperKit
import ServiceManagement

/// Where the root helper stands. Only `.enabled` can restart fseventsd
/// without a password prompt.
enum HelperStatus: String, Codable, Sendable {
    case enabled
    /// Registered; waiting for the user to switch it on in Login Items.
    case requiresApproval
    case notRegistered
    /// The plist isn't in this bundle (e.g. `swift run`).
    case notFound
    /// Ad-hoc build: no team to pin the XPC link to, so the helper refuses to serve.
    case unsigned

    var isReady: Bool { self == .enabled }

    var label: String {
        switch self {
        case .enabled: return "Enabled"
        case .requiresApproval: return "Waiting for your approval in Login Items"
        case .notRegistered: return "Not set up"
        case .notFound: return "Not available in this build"
        case .unsigned: return "Not available in unsigned builds"
        }
    }
}

/// The fseventsd helper as a launchd daemon managed by SMAppService. macOS
/// shows it under System Settings › General › Login Items, where the user
/// approves it once (and can switch it off again).
enum PrivilegedHelper {
    private static var service: SMAppService { .daemon(plistName: HelperConstants.daemonPlistName) }

    static var status: HelperStatus {
        guard SigningRequirement.forHelper != nil else { return .unsigned }
        switch service.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        // SMAppService also says .notFound for a daemon that was simply never
        // registered; only a missing plist really means "not in this build".
        default: return plistIsBundled ? .notRegistered : .notFound
        }
    }

    private static var plistIsBundled: Bool {
        let plist = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons/\(HelperConstants.daemonPlistName)")
        return FileManager.default.fileExists(atPath: plist.path)
    }

    /// Registers the daemon (macOS then asks for approval). Returns an error to show, or nil.
    @discardableResult
    static func register() -> String? {
        guard status != .unsigned else { return HelperStatus.unsigned.label }
        do {
            try service.register()
            return nil
        } catch {
            // "Operation not permitted" here just means approval is pending.
            return status == .requiresApproval ? nil : "macOS didn't allow this: \(error.localizedDescription)"
        }
    }

    static func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
