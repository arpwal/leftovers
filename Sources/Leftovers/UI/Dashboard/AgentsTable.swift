import SwiftUI

/// Memory attributed to each running coding agent, plus tool servers that
/// several agents each run their own copy of.
struct AgentsTable: View {
    let sessions: [AgentSession]
    let duplicates: [DuplicatedToolServer]
    @ObservedObject var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !duplicates.isEmpty { duplicateList }
            if sessions.isEmpty {
                ContentUnavailableView("No Coding Agents Running", systemImage: "sparkles",
                                       description: Text("Claude Code, Codex, Gemini CLI and others show up here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Text(session.kind.rawValue).fontWeight(.medium).lineLimit(1)
                }
            }
            .width(min: 120, ideal: 160)
            TableColumn("Project") { Text($0.project).lineLimit(1).help($0.root.workingDirectory ?? "") }
                .width(min: 70, ideal: 160)
            TableColumn("Memory") { Text(Format.bytes($0.totalFootprint)).monospacedDigit() }
                .width(min: 64, ideal: 84)
            TableColumn("Processes") { Text("\($0.members.count)").monospacedDigit() }
                .width(min: 40, ideal: 70)
            TableColumn("Tool servers") { Text("\($0.toolServers.count)").monospacedDigit() }
                .width(min: 40, ideal: 80)
            TableColumn("Running") { Text(Format.age($0.root.age)).monospacedDigit() }
                .width(min: 50, ideal: 70)
            TableColumn("") { session in Button("Quit") { quit(session) }.controlSize(.small) }
                .width(min: 50, ideal: 56)
        }
        .contextMenu(forSelectionType: AgentSession.ID.self) { ids in
            if let session = sessions.first(where: { ids.contains($0.id) }) {
                Button("Quit \(session.kind.rawValue) and What It Started…") { quit(session) }
            }
        }
    }

    private func quit(_ session: AgentSession) {
        guard Confirm.quitAgent(session) else { return }
        Task { await store.quitAgent(session) }
    }
}
