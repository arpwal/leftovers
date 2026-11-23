import AppKit

/// What happens when you close the dashboard or press ⌘Q in it.
enum CloseBehavior: String, CaseIterable, Identifiable {
    /// Default: the window closes, Leftovers keeps watching from the menu bar.
    case keepInMenuBar
    /// Closing the last window (or ⌘Q) quits the app entirely.
    case quitCompletely

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keepInMenuBar: return "Keep running in the menu bar"
        case .quitCompletely: return "Quit Leftovers"
        }
    }
}

/// How often the app re-reads memory.
enum RefreshInterval: Int, CaseIterable, Identifiable {
    case twoSeconds = 2
    case fiveSeconds = 5
    case fifteenSeconds = 15

    var id: Int { rawValue }
    var label: String { "Every \(rawValue) seconds" }
    var duration: Duration { .seconds(rawValue) }
}

/// UserDefaults keys, shared by `@AppStorage` in views and plain reads elsewhere.
enum SettingsKey {
    static let closeBehavior = "closeBehavior"
    static let refreshInterval = "refreshInterval"
    static let showReclaimableInMenuBar = "showReclaimableInMenuBar"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let showInDock = "showInDock"
    static let notifyAboutUpdates = "notifyAboutUpdates"
    static let warnWhenDiskLow = "warnWhenDiskLow"
    static let watchFseventsd = "watchFseventsd"
    static let autoRestartFseventsd = "autoRestartFseventsd"
    static let fseventsdCpuPercent = "fseventsdCpuPercent"
    static let fseventsdMemoryMB = "fseventsdMemoryMB"
}

/// Typed reads for code that cannot use `@AppStorage` (delegate, store loop).
enum AppSettings {
    static var closeBehavior: CloseBehavior {
        UserDefaults.standard.string(forKey: SettingsKey.closeBehavior).flatMap(CloseBehavior.init) ?? .keepInMenuBar
    }

    /// Shown in the Dock by default; the user can hide it in Settings.
    static var showInDock: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.showInDock) as? Bool ?? true
    }

    static var notifyAboutUpdates: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.notifyAboutUpdates) as? Bool ?? true
    }

    static var warnWhenDiskLow: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.warnWhenDiskLow) as? Bool ?? true
    }

    /// fseventsd watchdog: on by default, restarting automatically (with the helper).
    static var watchFseventsd: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.watchFseventsd) as? Bool ?? true
    }

    static var autoRestartFseventsd: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.autoRestartFseventsd) as? Bool ?? true
    }

    static var fseventsdLimits: FseventsdLimits {
        let defaults = UserDefaults.standard
        let cpu = defaults.object(forKey: SettingsKey.fseventsdCpuPercent) as? Double ?? Thresholds.fseventsdCpuPercent
        let megabytes = defaults.object(forKey: SettingsKey.fseventsdMemoryMB) as? Int ?? Int(Thresholds.fseventsdMemory >> 20)
        return FseventsdLimits(cpuPercent: cpu, memoryBytes: UInt64(max(megabytes, 1)) << 20,
                               sustainedFor: Thresholds.fseventsdSustainedCpu)
    }

    static var activationPolicy: NSApplication.ActivationPolicy { showInDock ? .regular : .accessory }

    static var refreshInterval: RefreshInterval {
        RefreshInterval(rawValue: UserDefaults.standard.integer(forKey: SettingsKey.refreshInterval)) ?? .fiveSeconds
    }
}
