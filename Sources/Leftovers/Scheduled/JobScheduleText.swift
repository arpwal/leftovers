import Foundation

/// Human-readable schedules and next-run times for launchd jobs.
enum JobScheduleText {
    private static let weekdays = Calendar.current.shortWeekdaySymbols   // index 0 = Sunday

    static func describe(_ schedule: JobSchedule) -> String {
        switch schedule {
        case let .interval(seconds): return every(seconds)
        case .onLoad: return "At login"
        case .none: return "Manually"
        case let .calendar(entries): return calendar(entries)
        }
    }

    /// For interval jobs, `lastRun` anchors the estimate (launchd counts from
    /// the last run, not from now).
    static func nextRun(_ schedule: JobSchedule, lastRun: Date? = nil, after now: Date = Date()) -> Date? {
        switch schedule {
        case let .interval(seconds):
            let next = (lastRun ?? now).addingTimeInterval(TimeInterval(seconds))
            return max(next, now)
        case let .calendar(entries):
            return entries.compactMap {
                Calendar.current.nextDate(after: now, matching: $0, matchingPolicy: .nextTime)
            }.min()
        case .onLoad, .none: return nil
        }
    }

    private static func every(_ seconds: Int) -> String {
        if seconds % 3600 == 0 { return seconds == 3600 ? "Every hour" : "Every \(seconds / 3600) hours" }
        if seconds % 60 == 0 { return "Every \(seconds / 60) min" }
        return "Every \(seconds) s"
    }

    /// "Weekdays at 8:30 AM", "Mon, Wed at 9:00 AM", "Daily at 7:00 AM".
    private static func calendar(_ entries: [DateComponents]) -> String {
        let times = Set(entries.map { time($0) })
        guard times.count == 1, let at = times.first else { return "\(entries.count) times on a schedule" }
        let days = Set(entries.compactMap(\.weekday))
        if days.isEmpty { return "Daily at \(at)" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays at \(at)" }
        return days.sorted().map { weekdays[$0 - 1] }.joined(separator: ", ") + " at \(at)"
    }

    private static func time(_ components: DateComponents) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: components.hour ?? 0, minute: components.minute ?? 0))
        return date.map { $0.formatted(date: .omitted, time: .shortened) } ?? "?"
    }
}
