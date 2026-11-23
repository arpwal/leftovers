import SwiftUI

/// Settings › fseventsd: the watchdog's switches and limits, the helper's
/// state, the backoff, and the last restart.
struct FseventsdSettingsSection: View {
    @ObservedObject var watchdog: FseventsdWatchdog
    @AppStorage(SettingsKey.watchFseventsd) private var watch = true
    @AppStorage(SettingsKey.autoRestartFseventsd) private var autoRestart = true
    @AppStorage(SettingsKey.fseventsdCpuPercent) private var cpuPercent = Thresholds.fseventsdCpuPercent
    @AppStorage(SettingsKey.fseventsdMemoryMB) private var memoryMB = Int(Thresholds.fseventsdMemory >> 20)
    private static let memoryChoices = [50, 100, 250, 500, 1_024, 2_048]

    var body: some View {
        Toggle("Watch fseventsd", isOn: $watch)
        Toggle("Restart it automatically", isOn: $autoRestart)
            .disabled(!watch)
            .onChange(of: autoRestart) { _, enabled in watchdog.setAutoRestart(enabled) }
        Stepper(value: $cpuPercent, in: 5...100, step: 5) {
            Text("CPU above \(Int(watchdog.limits.cpuPercent))% for \(Format.age(Thresholds.fseventsdSustainedCpu))")
        }
        .disabled(!watch)
        Picker("Memory above", selection: $memoryMB) {
            ForEach(memoryOptions, id: \.self) { Text(Format.bytes(UInt64($0) << 20)).tag($0) }
        }
        .disabled(!watch)
        helperRow
        LabeledContent("Status", value: watchdog.status.label)
        if watchdog.state.paused { pausedRow }
        LabeledContent("Last restart", value: watchdog.lastRestart?.summary ?? "Never")
        Text("fseventsd is macOS's file-event service. After weeks of heavy file churn it can grow to many GB and keep a core busy. Restarting it is safe: macOS starts a fresh one. Automatic restarts use a small helper you allow once in Login Items; it can only restart fseventsd. At most one automatic restart every \(Format.age(watchdog.state.cooldown)); if it keeps coming back soon after, the wait doubles, and after three times automatic restarts pause.")
            .font(.caption).foregroundStyle(.secondary)
    }

    /// The fixed choices plus whatever value is set (e.g. a raised limit).
    private var memoryOptions: [Int] { Array(Set(Self.memoryChoices + [memoryMB])).sorted() }

    @ViewBuilder private var helperRow: some View {
        LabeledContent("Helper") {
            HStack {
                Text(watchdog.helperStatus.label).foregroundStyle(.secondary)
                switch watchdog.helperStatus {
                case .notRegistered: Button("Allow…") { watchdog.enableHelper() }
                case .requiresApproval: Button("Open Login Items") { PrivilegedHelper.openLoginItems() }
                case .enabled, .notFound, .unsigned, .notInApplications: EmptyView()
                }
            }
        }
    }

    @ViewBuilder private var pausedRow: some View {
        LabeledContent("Automatic restarts paused") {
            HStack {
                if watchdog.state.suggestion != nil { Button("Raise Limits") { watchdog.raiseLimits() } }
                Button("Resume") { watchdog.resumeAutomaticRestarts() }
            }
        }
    }
}
