import Foundation
import LeftoversHelperKit

/// Talks to the root helper over XPC. Each call opens a privileged connection
/// (a launchd daemon), accepted only when the other end is the helper signed
/// by our own team, and closes it afterwards.
enum HelperClient {
    enum ReadResult: Equatable {
        case reading(HelperReading)
        case notRunning
        /// The helper couldn't be reached; use the unprivileged reading instead.
        case unreachable
    }

    /// The helper waits up to 60 s for fseventsd to flush; leave room for SIGKILL.
    private static let restartTimeout: Duration = .seconds(HelperConstants.terminateGracePeriod + 20)
    private static let quickTimeout: Duration = .seconds(5)

    static func restartFseventsd() async -> RestartOutcome {
        let data = await invoke(timeout: restartTimeout) { helper, reply in helper.restartFseventsd(reply: reply) }
        return data.map(RestartOutcome.decode) ?? RestartOutcome(result: .failed, detail: "Couldn't reach the helper")
    }

    static func readFseventsd() async -> ReadResult {
        guard let data = await invoke(timeout: quickTimeout, { helper, reply in helper.readFseventsd(reply: reply) }) else {
            return .unreachable
        }
        if data.isEmpty { return .notRunning }
        return HelperReading.decode(data).map(ReadResult.reading) ?? .unreachable
    }

    /// The build of the app bundle the running helper started from.
    static func version() async -> String? {
        await invoke(timeout: quickTimeout) { helper, reply in helper.version(reply: reply) }
    }

    /// One call with a timeout. nil when unsigned, unreachable or too slow.
    private static func invoke<T: Sendable>(timeout: Duration,
                                            _ call: @escaping (FseventsdHelperProtocol, @escaping (T) -> Void) -> Void) async -> T? {
        guard let requirement = SigningRequirement.forHelper else { return nil }
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FseventsdHelperProtocol.self)
        connection.setCodeSigningRequirement(requirement)
        connection.resume()
        defer { connection.invalidate() }
        return await withTaskGroup(of: T?.self) { group in
            group.addTask { await send(call, over: connection) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                // Invalidating fires the error handler, which ends `send` too:
                // the group can't finish while a child is still waiting.
                connection.invalidate()
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Bridges the reply (or a connection error) to async; resumes exactly once.
    private static func send<T: Sendable>(_ call: @escaping (FseventsdHelperProtocol, @escaping (T) -> Void) -> Void,
                                          over connection: NSXPCConnection) async -> T? {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in once.resume(nil) }
            guard let helper = proxy as? FseventsdHelperProtocol else { once.resume(nil); return }
            call(helper) { once.resume($0) }
        }
    }
}

/// XPC can call both the reply and the error handler; only the first wins.
private final class ResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    init(_ continuation: CheckedContinuation<T?, Never>) { self.continuation = continuation }

    func resume(_ value: T?) {
        let pending = lock.withLock { () -> CheckedContinuation<T?, Never>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: value)
    }
}
