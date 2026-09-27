import Foundation

/// `launchctl list` in one call: which jobs are loaded, their PID if running,
/// and their last exit status.
enum LaunchctlStatus {
    struct Entry: Hashable {
        let pid: Int32?
        let lastExitStatus: Int32?
    }

    static func read() -> [String: Entry] {
        guard let output = Launchctl.run(["list"]) else { return [:] }
        var entries: [String: Entry] = [:]
        for line in output.split(separator: "\n").dropFirst() {   // header: PID Status Label
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count == 3 else { continue }
            entries[String(columns[2])] = Entry(pid: Int32(columns[0]), lastExitStatus: Int32(columns[1]))
        }
        return entries
    }
}

/// Runs /bin/launchctl and returns its output, or nil on failure.
enum Launchctl {
    static let domain = "gui/\(getuid())"

    @discardableResult
    static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
