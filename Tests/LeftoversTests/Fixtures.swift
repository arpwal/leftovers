import Darwin
import Foundation
@testable import Leftovers

/// Builds process snapshots for tests. Defaults describe an ordinary,
/// idle, hour-old process owned by the current user.
enum Fixture {
    static let gib: UInt64 = 1 << 30
    static let mib: UInt64 = 1 << 20

    static func process(pid: pid_t = 1000, ppid: pid_t = 1, uid: uid_t = getuid(), name: String = "node",
                        path: String = "/opt/homebrew/bin/node", cwd: String? = nil, ageHours: Double = 1,
                        footprint: UInt64 = 100 << 20, resident: UInt64 = 100 << 20) -> ProcessSnapshot {
        ProcessSnapshot(pid: pid, ppid: ppid, uid: uid, name: name, executablePath: path, workingDirectory: cwd,
                        startDate: Date().addingTimeInterval(-ageHours * 3600), footprintBytes: footprint,
                        residentBytes: resident, cpuTimeNanos: 0, kind: ProcessKind.classify(path: path))
    }

    /// Runs a command, failing the test on a non-zero exit.
    @discardableResult
    static func sh(_ command: String, in directory: String, environment: [String: String] = [:]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        try process.run()
        process.waitUntilExit()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else { throw ShellError(command: command, output: text) }
        return text
    }

    static func temporaryDirectory() -> String {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("leftovers-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        // realpath, not resolvingSymlinksInPath: the latter strips /private,
        // but git and the kernel report /private/var/…
        return URL(fileURLWithPath: path).withUnsafeFileSystemRepresentation { pointer in
            pointer.flatMap { realpath($0, nil) }.map { String(cString: $0) } ?? path
        }
    }
}

struct ShellError: Error, CustomStringConvertible {
    let command: String
    let output: String
    var description: String { "`\(command)` failed:\n\(output)" }
}
