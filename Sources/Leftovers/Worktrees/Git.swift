import Foundation

/// Runs git (and du) with a timeout; never throws, returns nil on failure.
enum Git {
    static func run(_ arguments: [String], in directory: String, timeout: TimeInterval = 10) -> String? {
        run(executable: "/usr/bin/git", ["-C", directory] + arguments, timeout: timeout)
    }

    /// Output plus success, for commands whose error text is worth showing.
    static func runWithError(_ arguments: [String], in directory: String) -> (ok: Bool, message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory] + arguments
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = Pipe()
        do { try process.run() } catch { return (false, error.localizedDescription) }
        process.waitUntilExit()
        let text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (process.terminationStatus == 0, text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func run(executable: String, _ arguments: [String], timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let deadline = DispatchTime.now() + timeout
        DispatchQueue.global().asyncAfter(deadline: deadline) { if process.isRunning { process.terminate() } }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }

    /// Disk used by a folder, via `du -sk` (fast, counts each file once).
    static func size(of path: String) -> UInt64? {
        guard let out = run(executable: "/usr/bin/du", ["-sk", path], timeout: 60),
              let kb = UInt64(out.split(separator: "\t").first ?? "") else { return nil }
        return kb * 1024
    }
}
