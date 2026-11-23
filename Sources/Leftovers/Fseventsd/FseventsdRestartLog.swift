import Foundation
import LeftoversHelperKit

/// One fseventsd restart attempt: when, why, how, and what it was using.
struct FseventsdRestartEntry: Codable, Equatable, Sendable {
    enum Trigger: String, Codable, Sendable {
        case automatic, manual, commandLine
    }

    enum Method: String, Codable, Sendable {
        /// The approved root helper (SMAppService daemon).
        case helper
        /// macOS's own administrator password prompt (`osascript`).
        case administratorPrompt
    }

    let date: Date
    let trigger: Trigger
    let method: Method
    let cpuPercentBefore: Double?
    let memoryBytesBefore: UInt64?
    let result: RestartResult
    /// For `.forceKilled` this says SIGKILL was used (its unsaved journal was lost).
    let detail: String
    /// The fseventsd launchd started afterwards; nil if none appeared in time.
    let newPid: Int32?

    var succeeded: Bool { result == .terminated || result == .forceKilled }

    /// "Restarted 2h 5m ago (automatic) · was 20 GB, 118% CPU".
    var summary: String {
        let verb = result == .forceKilled ? "Force-restarted (SIGKILL)" : succeeded ? "Restarted" : "Restart failed"
        let when = "\(verb) \(Format.age(Date().timeIntervalSince(date))) ago (\(trigger.label))"
        guard let memory = memoryBytesBefore else { return when }
        return "\(when) · was \(Format.bytes(memory)), \(Format.cpu(cpuPercentBefore)) CPU"
    }
}

extension FseventsdRestartEntry.Trigger {
    var label: String {
        switch self {
        case .automatic: return "automatic"
        case .manual: return "manual"
        case .commandLine: return "command line"
        }
    }
}

/// Every restart, newest last, in Application Support. Shared by the app and
/// the command line, so `--fseventsd` shows restarts made by either.
struct FseventsdRestartLog {
    private static let keep = 50
    var url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Leftovers/fseventsd-restarts.json")

    func load() -> [FseventsdRestartEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([FseventsdRestartEntry].self, from: data)) ?? []
    }

    var last: FseventsdRestartEntry? { load().last }

    /// Last automatic attempt, for the cooldown. Failed attempts count too,
    /// so a broken helper isn't retried on every refresh.
    var lastAutomatic: FseventsdRestartEntry? { load().last { $0.trigger == .automatic } }

    func append(_ entry: FseventsdRestartEntry) {
        let entries = Array((load() + [entry]).suffix(Self.keep))
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(entries).write(to: url, options: .atomic)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
