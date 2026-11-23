import Darwin
import Foundation

/// One restart at a time across processes (the app and the CLI): an
/// exclusive, non-blocking flock on a file in Application Support. The
/// helper has its own in-process lock as well. Released on deinit (and by
/// the kernel if the process dies).
final class RestartLock {
    private static let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Leftovers/fseventsd-restart.lock").path
    private let descriptor: Int32

    /// nil when another restart holds the lock.
    init?() {
        try? FileManager.default.createDirectory(atPath: (Self.path as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        let fd = open(Self.path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { return nil }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); return nil }
        descriptor = fd
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
