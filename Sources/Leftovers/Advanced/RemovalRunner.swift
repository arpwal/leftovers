import AppKit

/// Carries out a `Removal`. Folder removals are validated the same way as
/// cache emptying; everything else goes through the tool that owns the data
/// (docker, simctl, tmutil, ollama) so its own bookkeeping stays right.
enum RemovalRunner {
    enum Outcome: Equatable {
        case removed
        case failed(String)
    }

    static func run(_ removal: Removal, ollamaRunning: Bool) -> Outcome {
        switch removal {
        case let .folder(path): return removeFolder(path)
        case let .ollamaModel(name, manifest, root): return removeOllama(name: name, manifest: manifest, root: root, serverRunning: ollamaRunning)
        case let .docker(prune):
            guard let docker = DockerScanner.binary else { return .failed("Docker isn't installed.") }
            return tool(docker, prune.arguments, timeout: 600)
        case let .simulatorDevice(udid): return tool("/usr/bin/xcrun", ["simctl", "delete", udid], timeout: 120)
        case let .simulatorRuntime(id): return tool("/usr/bin/xcrun", ["simctl", "runtime", "delete", id], timeout: 300)
        case .timeMachineSnapshot: return .failed("Needs your password; use removeSnapshot.")
        }
    }

    static func removeFolder(_ path: String, home: String = NSHomeDirectory()) -> Outcome {
        if let refusal = CachePurger.validate(path, home: home) { return .failed("Refused: \(refusal)") }
        do { try FileManager.default.removeItem(atPath: path); return .removed }
        catch { return .failed(error.localizedDescription) }
    }

    /// With the Ollama app running, its CLI removes the model; otherwise the
    /// manifest and the blobs no other model uses are deleted directly.
    static func removeOllama(name: String, manifest: String, root: String, serverRunning: Bool) -> Outcome {
        if serverRunning, let cli = ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama"].first(where: FileManager.default.isExecutableFile(atPath:)) {
            return tool(cli, ["rm", name], timeout: 60)
        }
        let rootPath = (root as NSString).standardizingPath
        let files = [manifest] + OllamaModels.unsharedBlobs(of: manifest, root: root)
        guard files.allSatisfy({ ($0 as NSString).standardizingPath.hasPrefix(rootPath + "/") }) else { return .failed("Refused: outside the model folder") }
        for file in files { try? FileManager.default.removeItem(atPath: file) }
        return FileManager.default.fileExists(atPath: manifest) ? .failed("Couldn't remove \(name)") : .removed
    }

    /// Deleting a local Time Machine snapshot needs an administrator: macOS
    /// shows its own password prompt (Leftovers never sees the password).
    @MainActor
    static func removeSnapshot(date: String) -> Outcome {
        guard SnapshotScanner.parse(date) != nil else { return .failed("Refused: not a snapshot date") }
        if case .removed = tool("/usr/bin/tmutil", ["deletelocalsnapshots", date], timeout: 60) { return .removed }
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"/usr/bin/tmutil deletelocalsnapshots \(date)\" with administrator privileges")?
            .executeAndReturnError(&error)
        return error == nil ? .removed : .failed(error?[NSAppleScript.errorMessage] as? String ?? "Cancelled")
    }

    private static func tool(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> Outcome {
        Git.run(executable: executable, arguments, timeout: timeout) != nil ? .removed : .failed("\((executable as NSString).lastPathComponent) refused")
    }
}
