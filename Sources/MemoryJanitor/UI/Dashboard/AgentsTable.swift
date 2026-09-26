import SwiftUI

/// Memory attributed to each running coding agent, plus tool servers that
/// several agents each run their own copy of.
struct AgentsTable: View {
    let sessions: [AgentSession]
    let duplicates: [DuplicatedToolServer]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !duplicates.isEmpty { duplicateList }
            if sessions.isEmpty {
                ContentUnavailableView("No Coding Agents Running", systemImage: "sparkles",
                                       description: Text("Claude Code, Codex, Gemini CLI and others show up here."))
            } else {
                table
            }
        }
    }

    private var duplicateList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duplicated tool servers").font(.headline)
            ForEach(duplicates) { duplicate in
                HStack {
                    Image(systemName: "square.on.square").foregroundStyle(Palette.amber500)
                    Text(duplicate.name).fontWeight(.medium)
                    Text("\(duplicate.processCount) processes in \(duplicate.sessionCount) sessions").foregroundStyle(.secondary)
                    Spacer()
                    Text(Format.bytes(duplicate.totalFootprint)).monospacedDigit()
                }
                .font(.callout)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var table: some View {
        Table(sessions) {
            TableColumn("Agent") { session in
                HStack(spacing: 10) {
                    AgentIcon(kind: session.kind, side: 22)
                    Text(session.kind.rawValue).fontWeight(.medium)
                }
            }
            .width(min: 150, ideal: 170)
            TableColumn("Project") { Text($0.project).lineLimit(1).help($0.root.workingDirectory ?? "") }
                .width(min: 140, ideal: 200)
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
