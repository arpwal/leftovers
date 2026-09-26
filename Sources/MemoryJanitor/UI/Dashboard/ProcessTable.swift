import SwiftUI

/// Processes with their app logos, largest footprint first.
struct ProcessTable: View {
    let processes: [ClassifiedProcess]
    let store: MonitorStore

    var body: some View {
        Table(processes) {
            TableColumn("Process") { process in
                HStack(spacing: 10) {
                    ProcessIcon(snapshot: process.snapshot, side: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(process.snapshot.name).fontWeight(.medium).lineLimit(1)
                        Text(process.verdict.explanation.isEmpty ? process.snapshot.executablePath : process.verdict.explanation)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                            .help(process.snapshot.executablePath)
                    }
                }
            }
            .width(min: 260, ideal: 380)
            TableColumn("Memory") { Text(Format.bytes($0.snapshot.footprintBytes)).monospacedDigit() }
                .width(80)
            TableColumn("In RAM") { Text(Format.bytes($0.snapshot.residentBytes)).monospacedDigit().foregroundStyle(.secondary) }
                .width(80)
            TableColumn("CPU") { Text(Format.cpu($0.cpuPercent)).monospacedDigit() }
                .width(55)
            TableColumn("Running") { Text(Format.age($0.snapshot.age)).monospacedDigit() }
                .width(70)
            TableColumn("") { ProcessActions(store: store, process: $0) }
                .width(90)
        }
        .contextMenu(forSelectionType: ClassifiedProcess.ID.self) { ids in
            if let process = processes.first(where: { ids.contains($0.id) }) { rowMenu(process) }
        }
    }

    @ViewBuilder private func rowMenu(_ process: ClassifiedProcess) -> some View {
        if process.verdict.isKillable {
            Button("Quit \(process.snapshot.name)…") { ProcessCommands.quit(process, store: store) }
        }
        Button("Show in Finder") { ProcessCommands.revealInFinder(process) }
        Button("Copy Process ID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(process.snapshot.pid)", forType: .string)
        }
    }
}
