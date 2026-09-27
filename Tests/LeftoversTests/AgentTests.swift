import Foundation
import Testing
@testable import Leftovers

@Suite("Agents and tool servers")
struct AgentTests {
    @Test func detectsAgentsByPathAndArguments() {
        #expect(AgentKind.detect(path: "/Users/me/.local/share/claude/versions/2.1.283", name: "2.1.283", arguments: []) == .claudeCode)
        #expect(AgentKind.detect(path: "/opt/homebrew/bin/codex", name: "codex", arguments: []) == .codex)
        #expect(AgentKind.detect(path: "/opt/homebrew/bin/node", name: "node", arguments: ["node", "/usr/local/bin/gemini"]) == .geminiCLI)
        #expect(AgentKind.detect(path: "/opt/homebrew/bin/node", name: "node", arguments: ["node", "server.js"]) == nil)
    }

    @Test func namesToolServersFromArguments() {
        #expect(ToolServerLabel.label(for: ["npm", "exec", "@google-cloud/observability-mcp"]) == "observability-mcp")
        #expect(ToolServerLabel.label(for: ["node", "/x/cloudsql-mcp-proxy.mjs"]) == "cloudsql-mcp-proxy")
        #expect(ToolServerLabel.label(for: ["node", "/x/playwright-mcp@0.0.41"]) == "playwright-mcp")
        #expect(ToolServerLabel.label(for: ["node", "server.js"]) == nil)
    }

    @Test func groupsASessionAndCountsDuplicateServersAcrossSessions() {
        let claudePath = "/Users/me/.local/share/claude/versions/2.1.283"
        let a = Fixture.process(pid: 100, ppid: 1, name: "2.1.283", path: claudePath)
        let aServer = Fixture.process(pid: 101, ppid: 100, name: "node", footprint: 80 * Fixture.mib)
        let b = Fixture.process(pid: 200, ppid: 1, name: "2.1.283", path: claudePath)
        let bServer = Fixture.process(pid: 201, ppid: 200, name: "node", footprint: 70 * Fixture.mib)
        let args: (pid_t) -> [String] = { [101, 201].contains($0) ? ["npm", "exec", "@x/observability-mcp"] : [] }
        let sessions = AgentSessionBuilder([a, aServer, b, bServer], arguments: args).sessions()
        #expect(sessions.count == 2)
        #expect(sessions.allSatisfy { $0.members.count == 2 && $0.toolServers.count == 1 })
        let duplicates = DuplicateToolServerFinder.find(in: sessions)
        #expect(duplicates.count == 1)
        #expect(duplicates[0].sessionCount == 2 && duplicates[0].totalFootprint == 150 * Fixture.mib)
    }
}
