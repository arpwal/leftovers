import Foundation

/// What happened when fseventsd was asked to restart.
public enum RestartResult: String, Codable, Sendable {
    /// Exited after SIGTERM; launchd starts a fresh one.
    case terminated
    /// Ignored SIGTERM for the whole grace period and was killed.
    case forceKilled
    /// No fseventsd at the expected path was running.
    case notRunning
    /// Another restart is already in progress.
    case busy
    /// The kernel refused the signal, or the helper couldn't be reached.
    case failed
}

/// Typed reply of `FseventsdHelperProtocol.restartFseventsd`, carried as JSON.
public struct RestartOutcome: Codable, Sendable, Equatable {
    public let result: RestartResult
    public let detail: String

    public init(result: RestartResult, detail: String) {
        self.result = result
        self.detail = detail
    }

    public var succeeded: Bool { result == .terminated || result == .forceKilled }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

    public static func decode(_ data: Data) -> RestartOutcome {
        (try? JSONDecoder().decode(RestartOutcome.self, from: data))
            ?? RestartOutcome(result: .failed, detail: "Unreadable reply from the helper")
    }
}
