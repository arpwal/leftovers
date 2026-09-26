import SwiftUI

/// Processes with their app logos, largest footprint first.
struct ProcessTable: View {
    let processes: [ClassifiedProcess]
    let store: MonitorStore
    @State private var selection = Set<ClassifiedProcess.ID>()

    var body: some View {
        Table(processes, selection: $selection) {
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
            .width(min: 160, ideal: 340)
            TableColumn("Memory") { Text(Format.bytes($0.snapshot.footprintBytes)).monospacedDigit() }
                .width(min: 64, ideal: 84)
            TableColumn("In RAM") { Text(Format.bytes($0.snapshot.residentBytes)).monospacedDigit().foregroundStyle(.secondary) }
                .width(min: 60, ideal: 80)
            TableColumn("CPU") { Text(Format.cpu($0.cpuPercent)).monospacedDigit() }
                .width(min: 40, ideal: 56)
            TableColumn("Running") { Text(Format.age($0.snapshot.age)).monospacedDigit() }
                .width(min: 50, ideal: 70)
            TableColumn("") { ProcessActions(store: store, process: $0) }
                .width(min: 76, ideal: 90)
        }
        .contextMenu(forSelectionType: ClassifiedProcess.ID.self) { ids in
            if let process = processes.first(where: { ids.contains($0.id) }) { rowMenu(process) }
        } primaryAction: { ids in
            // Double-click (or Return) shows the process in Finder.
            processes.filter { ids.contains($0.id) }.forEach(ProcessCommands.revealInFinder)
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
