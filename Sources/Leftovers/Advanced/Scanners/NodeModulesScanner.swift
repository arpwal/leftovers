import Foundation

/// `node_modules` folders in your code folders (the same ones the worktree
/// scan uses), with when each was last installed. Sized afterwards.
enum NodeModulesScanner {
    static func scan(roots: [String] = RepoFinder.roots, inUse: [String: String] = [:]) -> ToolReport {
        let found = roots.flatMap(find)
        let items = found.map { item(for: $0, inUse: inUse) }
        return ToolReport(items: items, notice: items.isEmpty ? "No node_modules folders in your code folders." : nil)
    }

    /// `find` prunes at each node_modules, so nested ones are never listed twice.
    static func find(in root: String) -> [String] {
        guard FileManager.default.fileExists(atPath: root),
              let out = Git.run(executable: "/usr/bin/find", [root, "-maxdepth", "7", "(", "-name", ".git", "-o", "-name", "Library",
                                                             "-o", "-name", ".Trash", ")", "-prune", "-o", "-type", "d",
                                                             "-name", "node_modules", "-prune", "-print"], timeout: 90)
        else { return [] }
        return out.split(separator: "\n").map(String.init)
    }

    static func item(for path: String, inUse: [String: String]) -> CleanableItem {
        let project = (path as NSString).deletingLastPathComponent
        let parent = ((project as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
        return CleanableItem(id: "nm:" + path, title: (project as NSString).lastPathComponent, detail: parent,
                             lastUsed: lastInstall(path), removal: .folder(path), measurePath: path,
                             blocker: user(of: project, in: inUse).map { "In use by \($0)" })
    }

    /// The newest install marker npm, pnpm or Yarn leaves, else the folder's own date.
    static func lastInstall(_ path: String) -> Date? {
        let markers = [".package-lock.json", ".modules.yaml", ".yarn-integrity", ".yarn-state.yml"].map { path + "/" + $0 }
        let dates = markers.compactMap(AIModelScanner.modified)
        return dates.max() ?? AIModelScanner.modified(path)
    }

    /// Who is working in `project` or below it, if anyone.
    static func user(of project: String, in inUse: [String: String]) -> String? {
        inUse.first { $0.key == project || $0.key.hasPrefix(project + "/") }?.value
    }
}
