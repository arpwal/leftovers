import Foundation

/// Has a branch been squash-merged? GitHub's "Squash and merge" puts the
/// branch's changes on main as one new commit, so `git branch --merged` never
/// sees it. The standard check: build the branch's whole change as a single
/// commit on top of its merge base, then ask `git cherry` whether main already
/// has an equivalent change ("-" means it does).
///
/// Read-only: the probe commit is written to a throwaway object folder that
/// borrows the repository's objects (GIT_ALTERNATE_OBJECT_DIRECTORIES), so
/// the repository itself never gains an object.
enum SquashMergeCheck {
    static func isSquashMerged(branch: String, into main: String, repository: String) -> Bool {
        guard let objects = Git.run(["rev-parse", "--path-format=absolute", "--git-common-dir"], in: repository)
            .map({ ($0.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).appendingPathComponent("objects") })
        else { return false }
        let scratch = (NSTemporaryDirectory() as NSString).appendingPathComponent("leftovers-probe-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: scratch) }
        let readOnly = ["GIT_OBJECT_DIRECTORY": scratch, "GIT_ALTERNATE_OBJECT_DIRECTORIES": objects]

        guard let base = trimmed(Git.run(["merge-base", main, branch], in: repository)),
              let tree = trimmed(Git.run(["rev-parse", "\(branch)^{tree}"], in: repository)),
              tree != trimmed(Git.run(["rev-parse", "\(base)^{tree}"], in: repository)),   // no changes at all: not a squash
              let probe = trimmed(Git.run(["commit-tree", tree, "-p", base, "-m", "leftovers squash probe"],
                                          in: repository, environment: readOnly)),
              let cherry = Git.run(["cherry", main, probe], in: repository, timeout: 30, environment: readOnly)
        else { return false }
        return cherry.hasPrefix("-")
    }

    private static func trimmed(_ text: String?) -> String? {
        text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
