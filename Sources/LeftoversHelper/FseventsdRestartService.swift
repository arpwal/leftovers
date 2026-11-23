import Foundation
import LeftoversHelperKit
import os

/// The object exported over XPC. One restart at a time across all
/// connections; a second request while one runs gets `.busy`.
final class FseventsdRestartService: NSObject, FseventsdHelperProtocol {
    private static let log = Logger(subsystem: HelperConstants.helperIdentifier, category: "restart")

    func restartFseventsd(reply: @escaping (Data) -> Void) {
        guard HelperActivity.shared.beginRestart() else {
            reply(RestartOutcome(result: .busy, detail: "A restart is already in progress").encoded())
            return
        }
        let outcome = FseventsdTerminator.restart()
        HelperActivity.shared.endRestart()
        Self.log.notice("restart fseventsd: \(outcome.result.rawValue, privacy: .public) \(outcome.detail, privacy: .public)")
        reply(outcome.encoded())
    }
}
