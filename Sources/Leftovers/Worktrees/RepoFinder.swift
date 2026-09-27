import Foundation

/// Finds git repositories that may have worktrees: common code folders
/// (a few levels deep) plus wherever processes are working right now.
enum RepoFinder {
    private static let roots = ["Documents", "Developer", "Projects", "code", "Code", "src", "repos", "GitHub", "Sites", "work"]
        .map { (NSHomeDirectory() as NSString).appendingPathComponent($0) }
    private static let skip: Set<String> = ["node_modules", ".build", "build", "dist", "Library", "Pods",
                                            "DerivedData", "vendor", ".venv", "venv", ".cache", "target"]
    private static let maxDepth = 4

    static func repositories(alsoContaining directories: [String]) -> [String] {
        var found = Set<String>()
        for root in roots { scan(root, depth: 0, into: &found) }
        for directory in directories {   // e.g. agent working folders
            if let common = Git.run(["rev-parse", "--path-format=absolute", "--git-common-dir"], in: directory, timeout: 3) {
                found.insert((common.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).deletingLastPathComponent)
            }
        }
        return found.sorted()
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
