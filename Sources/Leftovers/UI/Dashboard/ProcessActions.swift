import SwiftUI

/// Quit + protect controls for one process. Quitting always confirms with a
/// standard alert; protected processes get no Quit button at all.
///
/// The store is passed explicitly, not via @EnvironmentObject: macOS `Table`
/// cells can re-render outside the environment and crash on a missing object.
struct ProcessActions: View {
    @ObservedObject var store: MonitorStore
    let process: ClassifiedProcess

    var body: some View {
        HStack(spacing: 8) {
            if store.busyIdentities.contains(process.id) {
                ProgressView().controlSize(.small)
            } else if process.verdict.isKillable {
                Button("Quit") { ProcessCommands.quit(process, store: store) }
                    .controlSize(.small)
            }
            if isProtectable {
                Button { store.toggleProtection(for: process.snapshot.name) } label: {
                    Image(systemName: isUserProtected ? "lock.fill" : "lock.open")
                }
                .buttonStyle(.borderless)
                .help(isUserProtected ? "Stop protecting \(process.snapshot.name)" : "Never flag or quit \(process.snapshot.name)")
            }
        }
    }

    private var isUserProtected: Bool { store.protectedNames.contains(process.snapshot.name) }
    /// Only offer the toggle when protection is the user's choice to make.
    private var isProtectable: Bool { process.verdict.isKillable || isUserProtected }
}

/// Actions shared by row buttons, context menus and the menu bar.
@MainActor
enum ProcessCommands {
    static func quit(_ process: ClassifiedProcess, store: MonitorStore) {
        guard Confirm.quit(process) else { return }
        Task { await store.terminate(process) }
    }

    static func cleanUpAll(store: MonitorStore) {
        guard Confirm.cleanUp(store.suspects, freeing: store.reclaimableBytes) else { return }
        Task { await store.terminateAllSuspects() }
    }

    static func revealInFinder(_ process: ClassifiedProcess) {
        let path = AppBundle.outerPath(of: process.snapshot.executablePath) ?? process.snapshot.executablePath
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
