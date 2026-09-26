import Foundation

/// How long the last reading took, shown to the user ("812 processes in 38 ms").
struct ScanStats: Equatable {
    let processCount: Int
    let processMilliseconds: Int
    let agentCount: Int
    let agentMilliseconds: Int

    var summary: String {
        "\(processCount) processes in \(processMilliseconds) ms · \(agentCount) agents in \(agentMilliseconds) ms"
    }

    var shortSummary: String {
        "\(processCount) processes · \(processMilliseconds + agentMilliseconds) ms"
    }
}
