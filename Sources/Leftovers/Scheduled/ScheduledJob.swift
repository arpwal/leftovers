import Foundation

/// When a background job runs, as launchd defines it.
enum JobSchedule: Hashable {
    /// `StartCalendarInterval` entries (launchd weekday: 0 or 7 = Sunday).
    case calendar([DateComponents])
    /// `StartInterval`, in seconds.
    case interval(Int)
    /// Runs at load or stays alive; no timer.
    case onLoad
    case none
}

/// Notes a creator (such as Claude) leaves beside a job so it is never a mystery.
struct JobMetadata: Codable, Hashable {
    var purpose: String
    var createdBy: String
    var createdAt: Date
    var endsOn: Date?
}

/// One LaunchAgent in the user's account.
struct ScheduledJob: Identifiable, Hashable {
    let label: String
    let plistPath: String
    let program: String
    let schedule: JobSchedule
    let logPath: String?
    let isLoaded: Bool
    let pid: Int32?
    /// launchd's last exit status; nil if it hasn't run since loading.
    let lastExitStatus: Int32?
    let metadata: JobMetadata?

    var id: String { label }
    var isFromClaude: Bool { metadata?.createdBy.localizedCaseInsensitiveContains("claude") ?? false }
    var isRunning: Bool { pid != nil }
    var hasFailed: Bool { (lastExitStatus ?? 0) != 0 }

    /// Friendly name: the metadata purpose, else the label.
    var title: String { metadata?.purpose ?? label }

    /// Last time it wrote to its log, as a stand-in for "last ran".
    var lastActivity: Date? {
        guard let logPath else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: logPath))?[.modificationDate] as? Date
    }
}
