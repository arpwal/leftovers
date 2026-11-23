import Foundation
import LeftoversHelperKit

/// Talks to the root helper over XPC. The connection is privileged (a
/// launchd daemon) and only accepted when the other end is the helper signed
/// by our own team. One call per connection; nothing is kept open.
enum HelperClient {
    /// The helper waits up to 60 s for fseventsd to flush; leave room for SIGKILL.
    private static let timeout: Duration = .seconds(HelperConstants.terminateGracePeriod + 20)

    static func restartFseventsd() async -> RestartOutcome {
        guard let requirement = SigningRequirement.forHelper else {
            return RestartOutcome(result: .failed, detail: HelperStatus.unsigned.label)
        }
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FseventsdHelperProtocol.self)
        connection.setCodeSigningRequirement(requirement)
        connection.resume()
        defer { connection.invalidate() }
        return await withTaskGroup(of: RestartOutcome.self) { group in
            group.addTask { await call(connection) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                // Invalidating fires the error handler, which ends `call` too:
                // the group can't finish while a child is still waiting.
                connection.invalidate()
                return RestartOutcome(result: .failed, detail: "The helper didn't answer in time")
            }
            let first = await group.next() ?? RestartOutcome(result: .failed, detail: "No answer")
            group.cancelAll()
            return first
        }
    }

    /// Bridges the reply (or a connection error) to async; resumes exactly once.
    private static func call(_ connection: NSXPCConnection) async -> RestartOutcome {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                once.resume(RestartOutcome(result: .failed, detail: "Couldn't reach the helper: \(error.localizedDescription)"))
            }
            guard let helper = proxy as? FseventsdHelperProtocol else {
                once.resume(RestartOutcome(result: .failed, detail: "The helper has the wrong interface"))
                return
            }
            helper.restartFseventsd { once.resume(RestartOutcome.decode($0)) }
        }
    }
}

/// XPC can call both the reply and the error handler; only the first wins.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<RestartOutcome, Never>?

    init(_ continuation: CheckedContinuation<RestartOutcome, Never>) { self.continuation = continuation }

    func resume(_ outcome: RestartOutcome) {
        let pending = lock.withLock { () -> CheckedContinuation<RestartOutcome, Never>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: outcome)
    }
}
