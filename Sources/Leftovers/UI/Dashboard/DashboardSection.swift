import Foundation

/// The dashboard's sidebar destinations.
enum DashboardSection: String, CaseIterable, Identifiable, Hashable {
    case leaks, apps, agents, scheduled, processes, protected

    var id: String { rawValue }
    /// File-name form for `--snapshot`.
    var slug: String { rawValue }

    var title: String {
        switch self {
        case .leaks: return "Likely Leaks"
        case .apps: return "Apps"
        case .agents: return "Agents"
        case .scheduled: return "Scheduled"
        case .processes: return "All Processes"
        case .protected: return "Protected"
        }
    }

    var symbol: String {
        switch self {
        case .leaks: return "drop.triangle"
        case .apps: return "square.grid.2x2"
        case .agents: return "sparkles"
        case .scheduled: return "clock.arrow.circlepath"
        case .processes: return "list.bullet"
        case .protected: return "lock.shield"
        }
    }

    var subtitle: String {
        switch self {
        case .leaks: return "Memory held by processes that stopped doing useful work."
        case .apps: return "Every app with all of its helper processes, by memory."
        case .agents: return "Memory used by each coding-agent session and everything it started."
        case .scheduled: return "Background jobs in your account, including the ones Claude set up."
        case .processes: return "Your processes that you can quit."
        case .protected: return "macOS and system processes. Leftovers never quits these."
        }
    }
}
