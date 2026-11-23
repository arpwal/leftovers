import Foundation
import LeftoversHelperKit
import ServiceManagement

/// Where the root helper stands. Only `.enabled` can read fseventsd as root
/// and restart it without a password prompt.
enum HelperStatus: String, Codable, Sendable {
    case enabled
    /// Registered; waiting for the user to switch it on in Login Items.
    case requiresApproval
    case notRegistered
    /// The plist isn't in this bundle (`swift run`, debug builds).
    case notFound
    /// Ad-hoc build: no team to pin the XPC link to, so the helper refuses to serve.
    case unsigned
    /// macOS only registers daemons for an app installed in Applications.
    case notInApplications

    var isReady: Bool { self == .enabled }
    /// The user can do something about it from Leftovers.
    var canRegister: Bool { self == .notRegistered || self == .requiresApproval }

    var label: String {
        switch self {
        case .enabled: return "Allowed"
        case .requiresApproval: return "Waiting for your approval in Login Items"
        case .notRegistered: return "Not set up"
        case .notFound: return "Not available in this build"
        case .unsigned: return "Not available in unsigned builds"
        case .notInApplications: return "Move Leftovers to Applications first"
        }
    }
}

/// The fseventsd helper as a launchd daemon managed by SMAppService. macOS
/// lists it under System Settings › General › Login Items, where the user
/// allows it once (and can switch it off again).
enum PrivilegedHelper {
    private static var service: SMAppService { .daemon(plistName: HelperConstants.daemonPlistName) }

    /// Checked in order: the build can't have a helper, then what launchd says.
    static var status: HelperStatus {
        guard plistIsBundled else { return .notFound }
        guard SigningRequirement.forHelper != nil else { return .unsigned }
        guard isInApplications else { return .notInApplications }
        switch service.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        // SMAppService also says .notFound for a daemon never registered.
        default: return .notRegistered
        }
    }

    /// Registers the daemon (macOS then asks for approval). Returns an error to show, or nil.
    @discardableResult
    static func register() -> String? {
        let current = status
        guard current.canRegister else { return current.label }
        do {
            try service.register()
            return nil
        } catch {
            // "Operation not permitted" here just means approval is pending.
            return status == .requiresApproval ? nil : "macOS didn't allow this: \(error.localizedDescription)"
        }
    }

    /// Removes the daemon (Settings: automatic restarts off).
    static func unregister() {
        guard status == .enabled || status == .requiresApproval else { return }
        try? service.unregister()
    }

    static func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }

    private static var plistIsBundled: Bool {
        let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/\(HelperConstants.daemonPlistName)")
        return FileManager.default.fileExists(atPath: plist.path)
    }

    private static var isInApplications: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }
}
