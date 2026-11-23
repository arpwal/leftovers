import Foundation
import UserNotifications

/// fseventsd notifications: "it's running away" (with a Restart button) and
/// "it was restarted". Responses are routed by `UpdateNotifier`, the app's
/// notification-center delegate. Rate limits live in `WatchdogPolicy`.
enum FseventsdNotifier {
    static let alertIdentifier = "leftovers.fseventsd.alert"
    static let restartedIdentifier = "leftovers.fseventsd.restarted"
    static let category = "leftovers.fseventsd"
    static let restartAction = "leftovers.fseventsd.restart"

    static func isFseventsd(_ identifier: String) -> Bool {
        identifier == alertIdentifier || identifier == restartedIdentifier
    }

    /// Adds the Restart button to alerts. Call once at launch.
    static func registerCategory() {
        let restart = UNNotificationAction(identifier: restartAction, title: "Restart fseventsd", options: [])
        let category = UNNotificationCategory(identifier: category, actions: [restart], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func postAlert(_ health: FseventsdHealth, reason: WatchdogAlertReason) {
        post(identifier: alertIdentifier, title: "fseventsd is running away",
             body: "It's using \(health.reason). Restarting it frees that; macOS starts a fresh one." + hint(reason),
             withRestartButton: true)
    }

    static func postRestarted(_ entry: FseventsdRestartEntry) {
        let was = entry.memoryBytesBefore.map { " It was using \(Format.bytes($0)) and \(Format.cpu(entry.cpuPercentBefore)) CPU." } ?? ""
        post(identifier: restartedIdentifier,
             title: entry.succeeded ? "Restarted fseventsd" : "Couldn't restart fseventsd",
             body: entry.succeeded ? "macOS started a fresh one." + was : entry.detail, withRestartButton: !entry.succeeded)
    }

    private static func hint(_ reason: WatchdogAlertReason) -> String {
        switch reason {
        case .autoRestartOff: return ""
        case .helperNotReady: return " To restart it automatically, allow Leftovers in Login Items."
        case .withinCooldown: return " It was already restarted automatically in the last \(Format.age(Thresholds.fseventsdRestartCooldown))."
        }
    }

    private static func post(identifier: String, title: String, body: String, withRestartButton: Bool) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if withRestartButton { content.categoryIdentifier = category }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        }
    }
}
