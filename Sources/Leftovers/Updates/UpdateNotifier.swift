import AppKit
import UserNotifications

/// Posts "an update is ready" as a regular macOS notification instead of a
/// window popping up over your work. Clicking it opens the update.
@MainActor
final class UpdateNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UpdateNotifier()
    nonisolated private static let identifier = "leftovers.update"
    private var center: UNUserNotificationCenter { .current() }

    /// Idempotent; called before launch finishes so a notification tap that
    /// launched the app is delivered here.
    func start() { center.delegate = self }

    func notify(version: String) {
        guard AppSettings.notifyAboutUpdates else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Leftovers \(version) is ready"
            content.body = "Click to see what's new and update."
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil))
        }
    }

    func clear() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let action = response.actionIdentifier
        Task { @MainActor in
            if action == FseventsdNotifier.restartAction {
                await FseventsdWatchdog.shared.restart(trigger: .manual)
            } else if action == FseventsdNotifier.raiseAction {
                FseventsdWatchdog.shared.raiseLimits()
            } else if FseventsdNotifier.isFseventsd(identifier) {
                WindowCoordinator.shared.showDashboard(section: .leaks)
            } else if identifier == LowDiskWatcher.identifier {
                WindowCoordinator.shared.showDashboard(section: .disk)
            } else {
                UpdateController.shared.checkForUpdates()
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
