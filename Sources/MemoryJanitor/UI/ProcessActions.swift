import SwiftUI

/// Quit + protect controls for one process. Quitting always asks first;
/// protected processes get no quit button at all.
///
/// The store is passed explicitly, not via @EnvironmentObject: macOS `Table`
/// cells can re-render outside the environment and crash on a missing object.
struct ProcessActions: View {
    @ObservedObject var store: MonitorStore
    let process: ClassifiedProcess
    @State private var confirming = false

    var body: some View {
        HStack(spacing: 6) {
            if store.busyIdentities.contains(process.id) {
                ProgressView().controlSize(.small)
            } else if process.verdict.isKillable {
                Button("Quit", role: .destructive) { confirming = true }
                    .controlSize(.small)
            }
            protectButton
        }
        .confirmationDialog(
            "Quit \(process.snapshot.name) (pid \(process.snapshot.pid))?",
            isPresented: $confirming
        ) {
            Button("Quit and free \(Format.bytes(process.snapshot.footprintBytes))", role: .destructive) {
                Task { await store.terminate(process) }
            }
        } message: {
            Text(process.verdict.isSuspect ? process.verdict.explanation : "Unsaved work in it will be lost.")
        }
    }

    @ViewBuilder private var protectButton: some View {
        let name = process.snapshot.name
        let isUserProtected = store.protectedNames.contains(name)
        // Only offer the toggle when protection is the user's choice to make.
        if process.verdict.isKillable || isUserProtected {
            Button {
                store.toggleProtection(for: name)
            } label: {
                Image(systemName: isUserProtected ? "lock.fill" : "lock.open")
            }
            .buttonStyle(.borderless)
            .help(isUserProtected ? "Stop protecting \(name)" : "Never flag or quit \(name)")
        }
    }
}
