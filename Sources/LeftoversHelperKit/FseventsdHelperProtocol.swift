import Foundation

/// The helper's entire XPC surface. None of the calls take input: the
/// helper finds fseventsd itself, so a client can't point it elsewhere.
/// - `restartFseventsd`: the only call that changes anything. Replies with a
///   JSON `RestartOutcome`.
/// - `readFseventsd`: read-only; root can read fseventsd's footprint and CPU
///   time, a normal user can't. Replies with a JSON `HelperReading` (empty
///   Data when fseventsd isn't running).
/// - `version`: the build number of the app bundle the running helper was
///   started from, so the app can re-register a stale helper after an update.
@objc public protocol FseventsdHelperProtocol {
    func restartFseventsd(reply: @escaping (Data) -> Void)
    func readFseventsd(reply: @escaping (Data) -> Void)
    func version(reply: @escaping (String) -> Void)
}
