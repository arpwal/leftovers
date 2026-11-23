import Foundation

/// Tracks whether a restart is running and when the helper was last used,
/// so it can exit when idle: launchd starts it again on the next request,
/// and a root process shouldn't linger with nothing to do.
final class HelperActivity: @unchecked Sendable {
    static let shared = HelperActivity()
    private static let idleLimit: TimeInterval = 60
    private let lock = NSLock()
    private var restarting = false
    private var lastActivity = Date()

    /// Claims the single restart slot; false if one is already running.
    func beginRestart() -> Bool {
        lock.withLock {
            guard !restarting else { return false }
            restarting = true
            lastActivity = Date()
            return true
        }
    }

    func endRestart() { lock.withLock { restarting = false; lastActivity = Date() } }

    func touch() { lock.withLock { lastActivity = Date() } }

    /// Checks every 15 s and exits once idle for a minute.
    func exitWhenIdle() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 15, repeating: 15)
        timer.setEventHandler { [self] in if isIdle { exit(0) } }
        timer.resume()
        idleTimer = timer
    }

    private var idleTimer: DispatchSourceTimer?

    private var isIdle: Bool {
        lock.withLock { !restarting && Date().timeIntervalSince(lastActivity) > Self.idleLimit }
    }
}
