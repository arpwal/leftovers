import Foundation
import Security

/// Code-signing requirements that tie the app and the helper to each other:
/// both must be signed by Apple-issued certificates of the same team as the
/// running binary. An ad-hoc (unsigned) build has no team, so it gets no
/// requirement and the XPC link is refused in both directions.
public enum SigningRequirement {
    /// Accepted clients of the helper: only Leftovers itself.
    public static var forApp: String? { requirement(identifier: HelperConstants.appIdentifier) }
    /// What the app expects on the other end of the connection.
    public static var forHelper: String? { requirement(identifier: HelperConstants.helperIdentifier) }

    private static func requirement(identifier: String) -> String? {
        guard let team = currentTeamID() else { return nil }
        return "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }

    /// Team ID from this process's own signature, nil when ad-hoc signed.
    public static func currentTeamID() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return nil }
        let team = dictionary[kSecCodeInfoTeamIdentifier as String] as? String
        return team?.isEmpty == false ? team : nil
    }
}
