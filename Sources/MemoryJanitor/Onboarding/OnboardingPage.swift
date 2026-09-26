import Foundation

/// The three welcome pages: two problems nobody else solves, then the brand.
enum OnboardingPage: Int, CaseIterable, Identifiable {
    case hiddenLeaks, agentLeftovers, brand

    var id: Int { rawValue }
    var isLast: Bool { self == Self.allCases.last }
    var next: OnboardingPage? { OnboardingPage(rawValue: rawValue + 1) }

    var title: String {
        switch self {
        case .hiddenLeaks: return "Leaks hide in swap"
        case .agentLeftovers: return "Agents leave work running"
        case .brand: return "Memory Janitor"
        }
    }

    var message: String {
        switch self {
        case .hiddenLeaks:
            return "Activity Monitor shows what is in RAM. A leak that has been swapped out barely shows up there, even while it slows your whole Mac. Memory Janitor measures the full footprint."
        case .agentLeftovers:
            return "Every coding agent starts its own dev servers and MCP servers, and many keep running after the work is done. Memory Janitor finds them and adds up each session."
        case .brand:
            return "It finds memory that other apps leaked and gives it back. It never touches macOS itself, and it always asks before quitting anything."
        }
    }
}
