import Foundation
import LeftoversHelperKit

/// After a restart, launchd should start a new fseventsd within moments.
/// Confirms a different pid (or start time) appeared.
enum RespawnCheck {
    static let timeout: Duration = .seconds(60)
    private static let pollInterval: Duration = .seconds(1)

    /// The new fseventsd, or nil if none appeared within the timeout.
    static func waitForNew(replacing old: FseventsdIdentity?) async -> FseventsdIdentity? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let current = FseventsdProcess.locate(), current != old { return current }
            try? await Task.sleep(for: pollInterval)
        }
        return nil
    }
}
