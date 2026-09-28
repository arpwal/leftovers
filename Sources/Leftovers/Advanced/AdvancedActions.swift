import AppKit

/// Removing Advanced items: re-checks what's in use at click time, asks
/// once for the whole selection, then removes one by one.
@MainActor
enum AdvancedActions {
    static func remove(_ items: [CleanableItem], tool: AdvancedTool, store: AdvancedStore, monitor: MonitorStore) async {
        let ready = items.filter { $0.canRemove && currentBlocker($0, tool: tool, monitor: monitor) == nil }
        guard !ready.isEmpty else {
            store.lastActionMessage = "Nothing selected can be removed right now."
            return
        }
        let bytes = ready.compactMap(\.bytes).reduce(0, +)
        let title = ready.count == 1 ? "Remove \(ready[0].title)?" : "Remove \(ready.count) items?"
        guard Confirm.quit(title: title, detail: consequence(tool) + (bytes > 0 ? " Frees about \(Format.bytes(bytes))." : ""),
                           actionTitle: ready.count == 1 ? "Remove" : "Remove \(ready.count)") else { return }
        let ollamaRunning = DiskActions.runningNames(monitor).contains("ollama")
        var removed = Set<String>(), failures: [String] = []
        for item in ready {
            guard let removal = item.removal else { continue }
            let outcome: RemovalRunner.Outcome
            if case let .timeMachineSnapshot(date) = removal { outcome = RemovalRunner.removeSnapshot(date: date) }
            else { outcome = await Task.detached { RemovalRunner.run(removal, ollamaRunning: ollamaRunning) }.value }
            if outcome == .removed { removed.insert(item.id) } else if case let .failed(why) = outcome { failures.append("\(item.title): \(why)") }
        }
        store.forget(removed, in: tool)
        let freed = ready.filter { removed.contains($0.id) }.compactMap(\.bytes).reduce(0, +)
        store.lastActionMessage = "Removed \(removed.count) of \(ready.count), freeing about \(Format.bytes(freed))."
            + (failures.isEmpty ? "" : " Kept: " + failures.joined(separator: "; "))
    }

    /// node_modules: something may have started working in the project since the scan.
    static func currentBlocker(_ item: CleanableItem, tool: AdvancedTool, monitor: MonitorStore) -> String? {
        guard tool == .nodeModules, case let .folder(path)? = item.removal else { return item.blocker }
        return NodeModulesScanner.user(of: (path as NSString).deletingLastPathComponent, in: monitor.workingFolders)
    }

    static func consequence(_ tool: AdvancedTool) -> String {
        switch tool {
        case .aiModels: return "The model is deleted for good and downloads again if you need it."
        case .docker: return "Docker removes them; images are pulled and built again when needed. Volumes are kept."
        case .nodeModules: return "Deleted for good. Run npm, pnpm or yarn install to bring them back."
        case .simulators: return "Removed through Xcode's simulator tools. Runtimes download again from Xcode."
        case .snapshots: return "macOS will ask for your password. Backups on your backup disk are kept."
        }
    }
}
