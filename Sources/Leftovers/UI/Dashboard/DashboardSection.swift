import Foundation

/// The dashboard's sidebar destinations.
enum DashboardSection: String, CaseIterable, Identifiable, Hashable {
    case overview, disk, leaks, apps, agents, worktrees, scheduled, processes, protected
    case aiModels, docker, nodeModules, simulators, snapshots

    var id: String { rawValue }
    /// File-name form for `--snapshot`.
    var slug: String { rawValue }

    /// Sections built from the live memory reading (refreshed every few seconds).
    var usesMemoryReading: Bool { self != .worktrees && self != .scheduled && self != .disk && advancedTool == nil }

    /// Set for the sections in the sidebar's Advanced group.
    var advancedTool: AdvancedTool? { AdvancedTool(rawValue: rawValue) }
    static var main: [DashboardSection] { allCases.filter { $0.advancedTool == nil } }
    static var advanced: [DashboardSection] { allCases.filter { $0.advancedTool != nil } }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .disk: return "Disk"
        case .leaks: return "Likely Leaks"
        case .apps: return "Apps"
        case .agents: return "Agents"
        case .worktrees: return "Worktrees"
        case .scheduled: return "Scheduled"
        case .processes: return "All Processes"
        case .protected: return "Protected"
        case .aiModels, .docker, .nodeModules, .simulators, .snapshots: return advancedTool?.title ?? ""
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .disk: return "internaldrive"
        case .leaks: return "drop.triangle"
        case .apps: return "square.grid.2x2"
        case .agents: return "sparkles"
        case .worktrees: return "arrow.triangle.branch"
        case .scheduled: return "clock.arrow.circlepath"
        case .processes: return "list.bullet"
        case .protected: return "lock.shield"
        case .aiModels, .docker, .nodeModules, .simulators, .snapshots: return advancedTool?.symbol ?? ""
        }
    }

    var subtitle: String {
        switch self {
        case .overview: return "How much of your Mac's strength leftovers are using, and what cleanup gives back."
        case .disk: return "What macOS, your apps and your files use, and caches you can safely clear."
        case .leaks: return "Memory held by processes that stopped doing useful work."
        case .apps: return "Every app with all of its helper processes, by memory."
        case .agents: return "Memory used by each coding-agent session and everything it started."
        case .worktrees: return "Git worktrees agents left behind. Ones whose work is already on main are safe to remove."
        case .scheduled: return "Background jobs in your account, including the ones Claude set up."
        case .processes: return "Your processes that you can quit."
        case .protected: return "macOS and system processes. Leftovers never quits these."
        case .aiModels, .docker, .nodeModules, .simulators, .snapshots: return advancedTool?.subtitle ?? ""
        }
    }
}
