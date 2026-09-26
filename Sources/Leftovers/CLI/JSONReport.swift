import Foundation

/// Stable, machine-readable report for `--json`. Field names are a public
/// contract for scripts and agents: add fields, never rename them.
struct JSONReport: Encodable {
    struct System: Encodable {
        let totalBytes, swapUsedBytes, swapTotalBytes, compressedBytes: UInt64
        let availablePercent: Int
        let pressure: String
    }

    struct Process: Encodable {
        let pid: Int32
        let name, path, verdict, reason: String
        let footprintBytes, residentBytes: UInt64
        let cpuPercent: Double?
        let ageSeconds: Int
        let killable: Bool
    }

    struct Agent: Encodable {
        let agent, project: String
        let workingDirectory: String?
        let pid: Int32
        let footprintBytes: UInt64
        let processCount: Int
        let toolServers: [String]
    }

    struct Duplicate: Encodable {
        let name: String
        let processCount, sessionCount: Int
        let footprintBytes: UInt64
    }

    let takenAt: Date
    let system: System
    let likelyLeaks: [Process]
    let agents: [Agent]
    let duplicateToolServers: [Duplicate]

    static func render(_ report: MemoryReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(JSONReport(report)) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
