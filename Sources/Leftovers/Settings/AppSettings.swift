import Foundation

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
}

/// Typed reads for code that cannot use `@AppStorage` (delegate, store loop).
enum AppSettings {
    static var closeBehavior: CloseBehavior {
        UserDefaults.standard.string(forKey: SettingsKey.closeBehavior).flatMap(CloseBehavior.init) ?? .keepInMenuBar
    }

    static var refreshInterval: RefreshInterval {
        RefreshInterval(rawValue: UserDefaults.standard.integer(forKey: SettingsKey.refreshInterval)) ?? .fiveSeconds
    }
}
