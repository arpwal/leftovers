import Foundation

/// One running agent and every process it spawned (tool servers, builds, dev servers).
struct AgentSession: Identifiable, Hashable {
    let kind: AgentKind
    let root: ProcessSnapshot
    let members: [ProcessSnapshot]
    /// Tool (MCP) server processes this session runs.
    let toolServers: [ToolServerProcess]

    var id: ProcessIdentity { root.identity }
    var totalFootprint: UInt64 { members.reduce(0) { $0 + $1.footprintBytes } }
    /// The folder the agent works in — usually the repo or worktree name.
    var project: String {
        guard let cwd = root.workingDirectory else { return "—" }
        return (cwd as NSString).lastPathComponent
    }
}

/// One process belonging to a tool (MCP) server.
struct ToolServerProcess: Hashable {
    let name: String
    let footprintBytes: UInt64
}

/// A tool server that several agent sessions each started their own copy of.
struct DuplicatedToolServer: Identifiable, Hashable {
    let name: String
    let processCount: Int
    let sessionCount: Int
    let totalFootprint: UInt64

    var id: String { name }
}
