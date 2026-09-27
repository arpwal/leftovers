import Foundation
import Testing
@testable import Leftovers

@Suite("Scheduled jobs")
struct ScheduleTests {
    private func weekdays(_ hour: Int, _ minute: Int) -> JobSchedule {
        .calendar((1...5).map { DateComponents(hour: hour, minute: minute, weekday: $0 % 7 + 1) })
    }

    @Test func readableSchedules() {
        #expect(JobScheduleText.describe(weekdays(8, 30)).hasPrefix("Weekdays at "))
        #expect(JobScheduleText.describe(.calendar([DateComponents(hour: 7, minute: 0)])).hasPrefix("Daily at "))
        #expect(JobScheduleText.describe(.interval(1200)) == "Every 20 min")
        #expect(JobScheduleText.describe(.interval(3600)) == "Every hour")
        #expect(JobScheduleText.describe(.interval(21600)) == "Every 6 hours")
        #expect(JobScheduleText.describe(.onLoad) == "At login")
    }

    @Test func nextRunSkipsTheWeekend() throws {
        let saturday = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 15)))
        let next = try #require(JobScheduleText.nextRun(weekdays(8, 30), after: saturday))
        let parts = Calendar.current.dateComponents([.weekday, .hour, .minute], from: next)
        #expect(parts.weekday == 2 && parts.hour == 8 && parts.minute == 30)   // Monday 8:30
    }

    @Test func intervalJobsCountFromTheirLastRun() {
        let now = Date()
        let lastRun = now.addingTimeInterval(-300)
        #expect(JobScheduleText.nextRun(.interval(1200), lastRun: lastRun, after: now) == lastRun.addingTimeInterval(1200))
        #expect(JobScheduleText.nextRun(.interval(60), lastRun: lastRun, after: now) == now)   // overdue: "now"
    }

    @Test func readsRealPlistsStatusAndNotes() throws {
        let agents = Fixture.temporaryDirectory(), notes = Fixture.temporaryDirectory()
        let script: [String: Any] = ["Label": "com.test.poster", "ProgramArguments": ["/bin/bash", "/tmp/run.sh"],
                                     "StartCalendarInterval": ["Hour": 8, "Minute": 30], "StandardOutPath": "/tmp/poster.log"]
        let watcher: [String: Any] = ["Label": "com.test.watch", "ProgramArguments": ["/usr/local/bin/watch", "--fast"], "StartInterval": 1200]
        let service: [String: Any] = ["Label": "com.test.db", "Program": "/opt/homebrew/bin/postgres", "RunAtLoad": true]
        for (name, plist) in [("poster", script), ("watch", watcher), ("db", service)] {
            (plist as NSDictionary).write(toFile: "\(agents)/\(name).plist", atomically: true)
        }
        try Data(#"{"purpose":"Launch posts","createdBy":"Claude (Claude Code)","createdAt":"2026-09-26T23:00:00Z"}"#.utf8)
            .write(to: URL(fileURLWithPath: "\(notes)/com.test.poster.json"))
        let status: [String: LaunchctlStatus.Entry] = ["com.test.poster": .init(pid: nil, lastExitStatus: 0),
                                                       "com.test.watch": .init(pid: 42, lastExitStatus: 0)]
        let jobs = LaunchAgentReader(directory: agents).jobs(status: status, metadata: JobMetadataStore(directory: notes))
        let byLabel = Dictionary(uniqueKeysWithValues: jobs.map { ($0.label, $0) })

        let poster = try #require(byLabel["com.test.poster"])
        #expect(poster.program == "/tmp/run.sh")        // the script, not bash
        #expect(poster.isFromClaude && poster.title == "Launch posts")
        #expect(jobs.first?.label == "com.test.poster")  // Claude's jobs sort first
        #expect(byLabel["com.test.watch"]?.isRunning == true)
        #expect(byLabel["com.test.watch"]?.schedule == .interval(1200))
        #expect(byLabel["com.test.db"]?.isLoaded == false && byLabel["com.test.db"]?.schedule == .onLoad)
    }
}
