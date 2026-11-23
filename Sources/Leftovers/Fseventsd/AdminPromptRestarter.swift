import Foundation
import LeftoversHelperKit

/// Fallback when the helper isn't approved: macOS's own administrator
/// prompt runs `killall fseventsd` (Leftovers never sees the password).
/// Only for restarts the user asked for; automatic ones need the helper.
enum AdminPromptRestarter {
    private static let script =
        "do shell script \"/usr/bin/killall -TERM \(HelperConstants.fseventsdName)\" with administrator privileges"

    /// Blocks until the prompt is answered and killall returns.
    static func restart() -> RestartOutcome {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = Pipe()
        do { try process.run() } catch {
            return RestartOutcome(result: .failed, detail: error.localizedDescription)
        }
        process.waitUntilExit()
        guard process.terminationStatus != 0 else {
            return RestartOutcome(result: .terminated, detail: "fseventsd was asked to quit; launchd restarts it")
        }
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return RestartOutcome(result: .failed, detail: message.contains("-128") ? "Cancelled" : message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
