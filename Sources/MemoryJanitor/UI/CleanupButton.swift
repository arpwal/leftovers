import SwiftUI

/// "Clean up all likely leaks", behind a confirmation listing what will stop.
struct CleanupButton: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var confirming = false

    var body: some View {
        Button("Clean up \(Format.bytes(store.reclaimableBytes))") { confirming = true }
            .buttonStyle(.borderedProminent)
            .disabled(store.suspects.isEmpty)
            .confirmationDialog(
                "Quit \(store.suspects.count) likely leaks?",
                isPresented: $confirming
            ) {
                Button("Quit all and free \(Format.bytes(store.reclaimableBytes))", role: .destructive) {
                    Task { await store.terminateAllSuspects() }
                }
            } message: {
                Text(store.suspects.map(\.snapshot.name).joined(separator: ", "))
            }
    }
}
