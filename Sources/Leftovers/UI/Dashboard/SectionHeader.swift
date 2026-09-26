import SwiftUI

/// Large title, one-line explanation, and the section's primary action.
struct SectionHeader: View {
    @EnvironmentObject private var store: MonitorStore
    let section: DashboardSection

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title).font(.system(size: 26, weight: .semibold))
                Text(section.subtitle).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if section == .leaks {
                Button(store.suspects.isEmpty ? "Clean Up…" : "Clean Up \(Format.bytes(store.reclaimableBytes))…") { cleanUp() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.suspects.isEmpty)
            }
        }
    }

    private func cleanUp() { ProcessCommands.cleanUpAll(store: store) }
}
