import Foundation

/// The Scheduled section's data. Read on demand (the section refreshes it
/// while visible), off the main thread: a directory of small plists plus
/// one `launchctl list`.
@MainActor
final class ScheduledStore: ObservableObject {
    static let shared = ScheduledStore()
    @Published private(set) var jobs: [ScheduledJob] = []
    @Published private(set) var hasLoaded = false
    @Published var lastActionMessage: String?

    var failingCount: Int { jobs.filter(\.hasFailed).count }

    func reload() async {
        jobs = await Task.detached(priority: .userInitiated) { Self.readJobs() }.value
        hasLoaded = true
    }

    nonisolated static func readJobs() -> [ScheduledJob] {
        LaunchAgentReader().jobs(status: LaunchctlStatus.read(), metadata: JobMetadataStore())
    }

    func perform(_ message: String) async {
        lastActionMessage = message
        try? await Task.sleep(for: .milliseconds(300))   // let launchd settle
        await reload()
    }
}
