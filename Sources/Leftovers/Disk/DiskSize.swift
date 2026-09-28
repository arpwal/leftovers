import Foundation

/// Folder sizes via `du`, which counts each file once even across hard links.
enum DiskSize {
    /// Combined size of `paths` (0 for none); nil if `du` didn't finish, so a
    /// caller keeps the last known size instead of showing 0. Unreadable parts are skipped.
    static func total(of paths: [String]) -> UInt64? {
        guard !paths.isEmpty else { return 0 }
        // -c adds a final "total" line; du exits non-zero if any part was unreadable,
        // so run it through a shell that always succeeds and read what it printed.
        let quoted = paths.map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }.joined(separator: " ")
        guard let out = Git.run(executable: "/bin/sh", ["-c", "/usr/bin/du -skc \(quoted) 2>/dev/null; true"], timeout: 600),
              let last = out.split(separator: "\n").last,
              last.hasSuffix("\ttotal"),
              let kb = UInt64(last.split(separator: "\t").first ?? "") else { return nil }
        return kb * 1024
    }
}

/// One measurement in a disk scan, and what it found.
enum DiskMeasurement: Sendable {
    case target(CleanupTarget)
    case app(path: String, bundle: String, data: [String], caches: [String])

    enum Result: Sendable {
        case target(CleanupTarget, UInt64?)
        case app(path: String, app: UInt64?, data: UInt64?, caches: UInt64?)
    }

    func run() -> Result {
        switch self {
        case let .target(target): return .target(target, DiskSize.total(of: [target.path()]))
        case let .app(path, bundle, data, caches):
            return .app(path: path, app: DiskSize.total(of: [bundle]),
                        data: DiskSize.total(of: data), caches: DiskSize.total(of: caches))
        }
    }

    /// Runs `jobs` with at most `width` at once, handing each result to
    /// `deliver` on the main actor as soon as it's ready.
    static func runAll(_ jobs: [DiskMeasurement], width: Int, deliver: @MainActor @escaping (Result) -> Void) async {
        await withTaskGroup(of: Result.self) { group in
            var pending = jobs[...]
            for _ in 0..<min(width, pending.count) {
                let job = pending.removeFirst()
                group.addTask { job.run() }
            }
            for await result in group {
                await deliver(result)
                if let job = pending.popFirst() { group.addTask { job.run() } }
            }
        }
    }
}
