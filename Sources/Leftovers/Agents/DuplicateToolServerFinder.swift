import Foundation

/// Finds tool servers that more than one agent session runs its own copy of —
/// e.g. four Claude sessions each starting the same MCP server twice.
enum DuplicateToolServerFinder {
    static func find(in sessions: [AgentSession]) -> [DuplicatedToolServer] {
        var processes: [String: [ToolServerProcess]] = [:]
        var sessionCounts: [String: Int] = [:]
        for session in sessions {
            for server in session.toolServers { processes[server.name, default: []].append(server) }
            for name in Set(session.toolServers.map(\.name)) { sessionCounts[name, default: 0] += 1 }
        }
        return processes.compactMap { name, list in
            let sessionCount = sessionCounts[name] ?? 0
            guard sessionCount > 1 else { return nil }
            return DuplicatedToolServer(
                name: name,
                processCount: list.count,
                sessionCount: sessionCount,
                totalFootprint: list.reduce(0) { $0 + $1.footprintBytes }
            )
        }
        .sorted { $0.totalFootprint > $1.totalFootprint }
    }
}
