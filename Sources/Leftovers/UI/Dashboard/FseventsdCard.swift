import SwiftUI

/// fseventsd in Likely Leaks: shown while it's over its limits, restarting,
/// or was restarted in the last day. Says what it's using and why it's
/// flagged, with Restart and (without the helper) how to allow automatic restarts.
struct FseventsdCard: View {
    @ObservedObject var watchdog: FseventsdWatchdog
    private static let recentRestart: TimeInterval = 24 * 3_600

    static func isVisible(_ watchdog: FseventsdWatchdog) -> Bool {
        let recent = watchdog.lastRestart.map { Date().timeIntervalSince($0.date) < recentRestart } ?? false
        return watchdog.needsRestart || watchdog.isRestarting || recent
    }

    var body: some View {
        if Self.isVisible(watchdog) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: watchdog.needsRestart ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .font(.title2)
                    .foregroundStyle(watchdog.needsRestart ? Palette.amber500 : Palette.emerald500)
                VStack(alignment: .leading, spacing: 4) {
                    Text(watchdog.needsRestart ? "fseventsd is running away" : "fseventsd").font(.headline)
                    Text(detail).foregroundStyle(.secondary)
                    if let last = watchdog.lastRestart { Text(last.summary).font(.caption).foregroundStyle(.secondary) }
                    if let message = watchdog.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                actions
            }
            .padding(14)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var detail: String {
        guard let health = watchdog.health else { return "macOS's file-event service. Reading it…" }
        let state = health.needsRestart ? "Using \(health.reason)." : "Healthy: \(health.usage)."
        return "macOS's file-event service. \(state) Restarting it is safe: macOS starts a fresh one."
    }

    @ViewBuilder private var actions: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if watchdog.isRestarting {
                ProgressView().controlSize(.small)
            } else {
                Button(watchdog.helperStatus.isReady ? "Restart" : "Restart…") {
                    Task { await watchdog.restart(trigger: .manual) }
                }
                .buttonStyle(.borderedProminent)
            }
            if !watchdog.helperStatus.isReady, watchdog.helperStatus != .unsigned {
                Button("Allow automatic restarts…") { watchdog.enableHelper() }
                    .buttonStyle(.link).font(.caption)
            }
        }
    }
}
