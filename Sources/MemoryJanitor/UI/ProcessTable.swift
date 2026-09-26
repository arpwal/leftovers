import SwiftUI

/// Sortable-by-footprint table of processes with per-row actions.
struct ProcessTable: View {
    let processes: [ClassifiedProcess]
    let store: MonitorStore

    var body: some View {
        Table(processes) {
            TableColumn("Process") { process in
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.snapshot.name).fontWeight(.medium)
                    Text(process.snapshot.executablePath)
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .help(process.snapshot.executablePath)
                }
            }
            .width(min: 170, ideal: 220)
            TableColumn("Memory") { process in
                Text(Format.bytes(process.snapshot.footprintBytes)).monospacedDigit()
            }
            .width(80)
            TableColumn("In RAM") { process in
                Text(Format.bytes(process.snapshot.residentBytes)).monospacedDigit().foregroundStyle(.secondary)
            }
            .width(80)
            TableColumn("CPU") { process in
                Text(Format.cpu(process.cpuPercent)).monospacedDigit()
            }
            .width(55)
            TableColumn("Running") { process in
                Text(Format.age(process.snapshot.age)).monospacedDigit()
            }
            .width(70)
            TableColumn("Why") { process in
                Text(process.verdict.explanation)
                    .font(.caption).lineLimit(2)
                    .help(process.verdict.explanation)
            }
            .width(min: 140, ideal: 220)
            TableColumn("") { process in
                ProcessActions(store: store, process: process)
            }
            .width(110)
        }
    }
}
