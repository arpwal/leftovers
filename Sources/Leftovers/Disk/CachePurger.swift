import Foundation

/// Empties a cache folder: deletes what's inside, keeps the folder itself.
/// Refuses anything that isn't a real folder inside the home folder, and
/// never follows links (removing a link removes only the link).
enum CachePurger {
    enum Refusal: Error, Equatable {
        case outsideHome, notAFolder, isLink
    }

    struct Result: Equatable {
        var removed = 0
        var failed = 0
    }

    static func validate(_ path: String, home: String = NSHomeDirectory()) -> Refusal? {
        let standardized = (path as NSString).standardizingPath
        let root = (home as NSString).standardizingPath
        guard standardized.hasPrefix(root + "/"), standardized.count > root.count + 1,
              !standardized.contains("/../") else { return .outsideHome }
        if AppFinder.isSymlink(standardized) { return .isLink }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized, isDirectory: &isDirectory),
              isDirectory.boolValue else { return .notAFolder }
        return nil
    }

    /// Deletes permanently: these are caches, so the Trash would only move
    /// the space somewhere else.
    static func empty(_ path: String, home: String = NSHomeDirectory()) -> Swift.Result<Result, Refusal> {
        if let refusal = validate(path, home: home) { return .failure(refusal) }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        var result = Result()
        for name in names {
            do { try FileManager.default.removeItem(atPath: path + "/" + name); result.removed += 1 }
            catch { result.failed += 1 }
        }
        return .success(result)
    }
}
