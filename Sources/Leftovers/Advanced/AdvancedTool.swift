import Foundation

/// The "Advanced" sidebar group: bigger, rarer cleanups, each scanned only
/// when you open it. Raw values match their `DashboardSection` cases.
enum AdvancedTool: String, CaseIterable, Codable {
    case aiModels, docker, nodeModules, simulators, snapshots

    var title: String {
        switch self {
        case .aiModels: return "AI Models"
        case .docker: return "Docker"
        case .nodeModules: return "node_modules"
        case .simulators: return "Simulators"
        case .snapshots: return "Snapshots"
        }
    }

    var symbol: String {
        switch self {
        case .aiModels: return "brain"
        case .docker: return "shippingbox.circle"
        case .nodeModules: return "folder.badge.gearshape"
        case .simulators: return "iphone"
        case .snapshots: return "clock.arrow.2.circlepath"
        }
    }

    var subtitle: String {
        switch self {
        case .aiModels: return "Models downloaded by Ollama, Hugging Face and LM Studio. Each downloads again if you need it."
        case .docker: return "Images, stopped containers and build cache Docker keeps. Volumes are never touched."
        case .nodeModules: return "Installed packages in your projects, biggest first. One install brings them back."
        case .simulators: return "Simulators whose iOS version is gone, and simulator runtimes you may not need."
        case .snapshots: return "Local Time Machine snapshots and space macOS can free on its own."
        }
    }
}
