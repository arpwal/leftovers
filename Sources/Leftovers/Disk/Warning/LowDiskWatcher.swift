import Foundation
import UserNotifications

/// Warns once a day when the startup disk is under 10% free, pointing at the
/// Disk section. Checks every 15 minutes; off in Settings if unwanted.
@MainActor
final class LowDiskWatcher {
    static let shared = LowDiskWatcher()
    nonisolated static let identifier = "leftovers.low-disk"
    nonisolated static let threshold = 0.10
    nonisolated static let quietPeriod: TimeInterval = 24 * 60 * 60
    private static let lastWarnedKey = "lowDiskLastWarned"
    private var timer: Timer?

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            Task { @MainActor in LowDiskWatcher.shared.check() }
        }
    }

    func check() {
        guard let disk = DiskUsage.read() else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastWarnedKey) as? Date
        guard Self.shouldWarn(free: disk.free, total: disk.total, lastWarned: last, enabled: AppSettings.warnWhenDiskLow) else { return }
        UserDefaults.standard.set(Date(), forKey: Self.lastWarnedKey)
        post(free: disk.free, reclaimable: DiskStore.shared.cleanableBytes + WorktreeStore.shared.reclaimableBytes)
    }

    nonisolated static func shouldWarn(free: UInt64, total: UInt64, lastWarned: Date?, enabled: Bool, now: Date = Date()) -> Bool {
        guard enabled, total > 0, Double(free) / Double(total) < threshold else { return false }
        guard let lastWarned else { return true }
        return now.timeIntervalSince(lastWarned) >= quietPeriod
    }

    private func post(free: UInt64, reclaimable: UInt64) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your disk is almost full"
            content.body = "\(Format.bytes(free)) left."
                + (reclaimable > 0 ? " Leftovers found \(Format.bytes(reclaimable)) you can safely clear." : " See what's using it.")
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil))
        }
    }
}
