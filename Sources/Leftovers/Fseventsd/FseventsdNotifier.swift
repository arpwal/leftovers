import Foundation
import UserNotifications

/// fseventsd notifications. Alerts carry a Restart button, the "paused"
/// alert a Raise Limits button. Responses are routed by `UpdateNotifier`,
/// the app's notification-center delegate (set at launch, so a tap that
/// relaunches the app is still handled). Rate limits live in `WatchdogPolicy`.
enum FseventsdNotifier {
    static let restartedIdentifier = "leftovers.fseventsd.restarted"
    static let restartCategory = "leftovers.fseventsd.restart"
    static let raiseCategory = "leftovers.fseventsd.raise"
    static let restartAction = "leftovers.fseventsd.restart"
    static let raiseAction = "leftovers.fseventsd.raise"

    static func identifier(for alert: WatchdogAlert) -> String { "leftovers.fseventsd.\(alert.rawValue)" }

    static func isFseventsd(_ identifier: String) -> Bool { identifier.hasPrefix("leftovers.fseventsd.") }

    /// Adds the buttons. Call once, early at launch.
    static func registerCategories() {
        let restart = UNNotificationAction(identifier: restartAction, title: "Restart fseventsd", options: [])
        let raise = UNNotificationAction(identifier: raiseAction, title: "Raise Limits", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: restartCategory, actions: [restart], intentIdentifiers: []),
            UNNotificationCategory(identifier: raiseCategory, actions: [raise], intentIdentifiers: []),
        ])
    }

    static func post(_ alert: WatchdogAlert, health: FseventsdHealth?, state: WatchdogState) {
        let usage = health.map { "It's using \($0.reason)." } ?? ""
        switch alert {
        case .autoRestartOff, .helperNotReady, .withinCooldown:
            post(identifier: identifier(for: alert), title: "fseventsd is running away",
                 body: "\(usage) Restarting it frees that; macOS starts a fresh one." + hint(alert, state: state),
                 category: restartCategory)
        case .paused:
            post(identifier: identifier(for: alert), title: "Automatic fseventsd restarts paused",
                 body: "fseventsd's normal size on this Mac is above your limit: it came back \(state.quickRelapses) times soon after restarts. Raise the limit?\(suggestionText(state.suggestion))",
                 category: raiseCategory)
        case .noRespawn:
            post(identifier: identifier(for: alert), title: "fseventsd didn't come back",
                 body: "No new fseventsd started within a minute of the restart. Apps that watch files may miss changes until it does; restarting your Mac fixes it.",
                 category: nil)
        }
    }

    static func postRestarted(_ entry: FseventsdRestartEntry) {
        let was = entry.memoryBytesBefore.map { " It was using \(Format.bytes($0)) and \(Format.cpu(entry.cpuPercentBefore)) CPU." } ?? ""
        let title = entry.result == .forceKilled ? "Force-restarted fseventsd" : entry.succeeded ? "Restarted fseventsd" : "Couldn't restart fseventsd"
        let body = entry.result == .forceKilled ? entry.detail + "." + was : entry.succeeded ? "macOS started a fresh one." + was : entry.detail
        post(identifier: restartedIdentifier, title: title, body: body, category: entry.succeeded ? nil : restartCategory)
    }

    private static func hint(_ alert: WatchdogAlert, state: WatchdogState) -> String {
        switch alert {
        case .helperNotReady: return " To restart it automatically, allow Leftovers in Login Items."
        case .withinCooldown: return " It was restarted automatically less than \(Format.age(state.cooldown)) ago, so Leftovers is waiting."
        default: return ""
        }
    }

    private static func suggestionText(_ suggestion: LimitSuggestion?) -> String {
        guard let suggestion else { return "" }
        let parts = [suggestion.memoryMB.map { "memory to \(Format.bytes(UInt64($0) << 20))" },
                     suggestion.cpuPercent.map { "CPU to \(Int($0))%" }].compactMap { $0 }
        return parts.isEmpty ? "" : " Suggested: " + parts.joined(separator: ", ") + "."
    }

    private static func post(identifier: String, title: String, body: String, category: String?) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let category { content.categoryIdentifier = category }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        }
    }
}
