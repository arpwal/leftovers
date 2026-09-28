import Foundation

/// Finds git repositories that may have worktrees: common code folders
/// (a few levels deep) plus wherever processes are working right now.
enum RepoFinder {
    static let roots = ["Documents", "Developer", "Projects", "code", "Code", "src", "repos", "GitHub", "Sites", "work"]
        .map { (NSHomeDirectory() as NSString).appendingPathComponent($0) }
    private static let skip: Set<String> = ["node_modules", ".build", "build", "dist", "Library", "Pods",
                                            "DerivedData", "vendor", ".venv", "venv", ".cache", "target"]
    private static let maxDepth = 4

    static func repositories(alsoContaining directories: [String]) -> [String] {
        var found = Set<String>()
        for root in roots { scan(root, depth: 0, into: &found) }
        // Folders processes work in (often hundreds): only those not already
        // inside a found repository need a git call, and they run in parallel.
        let candidates = candidateFolders(directories, knownRepositories: found)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: candidates.count) { index in
            guard let common = Git.run(["rev-parse", "--path-format=absolute", "--git-common-dir"], in: candidates[index], timeout: 3)
            else { return }
            let repository = (common.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).deletingLastPathComponent
            lock.lock(); found.insert(repository); lock.unlock()
        }
        return found.sorted()
    }

    /// Unique folders under the home folder (not the home folder itself) that
    /// aren't inside a repository we already know.
    static func candidateFolders(_ directories: [String], knownRepositories: Set<String>,
                                 home: String = NSHomeDirectory()) -> [String] {
        Set(directories).filter { folder in
            folder.hasPrefix(home + "/")
                && !knownRepositories.contains { folder == $0 || folder.hasPrefix($0 + "/") }
        }.sorted()
    }

    /// A `.git` *directory* marks a main checkout; linked worktrees have a
    /// `.git` file and are listed by their main repository instead.
    private static func scan(_ directory: String, depth: Int, into found: inout Set<String>) {
        guard depth <= maxDepth,
              let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return }
        var isDirectory: ObjCBool = false
        let gitPath = (directory as NSString).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue { found.insert(directory) }
            return   // a repository or a linked worktree: its main repo lists it; don't descend
        }
        for entry in entries where !entry.hasPrefix(".") && !skip.contains(entry) {
            let child = (directory as NSString).appendingPathComponent(entry)
            if FileManager.default.fileExists(atPath: child, isDirectory: &isDirectory), isDirectory.boolValue {
                scan(child, depth: depth + 1, into: &found)
            }
        }
    }
}
