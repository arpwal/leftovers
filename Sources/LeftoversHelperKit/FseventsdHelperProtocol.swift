import Foundation

/// The helper's entire XPC surface: exactly one operation, taking no input.
/// The helper finds fseventsd itself, so a client can't point it elsewhere.
/// The reply is a JSON-encoded `RestartOutcome`.
@objc public protocol FseventsdHelperProtocol {
    func restartFseventsd(reply: @escaping (Data) -> Void)
}
