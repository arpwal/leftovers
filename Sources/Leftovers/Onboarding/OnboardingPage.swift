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
        case .agentLeftovers: return "Agents leave a mess behind"
        case .brand: return "Leftovers"
        }
    }

    var message: String {
        switch self {
        case .hiddenLeaks:
            return "Activity Monitor shows what is in RAM. A leak that has been swapped out barely shows up there, even while it slows your whole Mac. Leftovers measures the full footprint."
        case .agentLeftovers:
            return "Like kids running through the house, every coding agent sets up dev servers and MCP servers, then moves on and leaves them running. Leftovers finds what was left lying around."
        case .brand:
            return "Clean up what your apps and agents left running. Leftovers never touches macOS itself, and it always asks before quitting anything."
        }
    }
}
