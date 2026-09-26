import SwiftUI

/// Memory attributed to each running coding agent, plus tool servers that
/// several agents each run their own copy of.
struct AgentsView: View {
    let sessions: [AgentSession]
    let duplicates: [DuplicatedToolServer]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(duplicates) { duplicate in
                Label {
                    Text("\(duplicate.name): \(duplicate.processCount) processes across \(duplicate.sessionCount) sessions, \(Format.bytes(duplicate.totalFootprint))")
                } icon: {
                    Image(systemName: "square.on.square").foregroundStyle(Palette.amber500)
                }
                .font(.callout)
            }
            if sessions.isEmpty {
                Text("No coding agents running.").foregroundStyle(.secondary)
            } else {
                table
            }
        }
    }

    private var table: some View {
        Table(sessions) {
            TableColumn("Agent") { Text($0.kind.rawValue).fontWeight(.medium) }
                .width(min: 110, ideal: 130)
            TableColumn("Project") { Text($0.project).lineLimit(1).help($0.root.workingDirectory ?? "") }
                .width(min: 140, ideal: 220)
            TableColumn("Memory") { Text(Format.bytes($0.totalFootprint)).monospacedDigit() }
                .width(90)
            TableColumn("Processes") { Text("\($0.members.count)").monospacedDigit() }
                .width(75)
            TableColumn("Tool servers") { Text("\($0.toolServers.count)").monospacedDigit() }
                .width(90)
            TableColumn("Running") { Text(Format.age($0.root.age)).monospacedDigit() }
                .width(75)
        }
    }
}
