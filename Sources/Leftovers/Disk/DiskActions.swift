import AppKit

/// Emptying developer caches and app caches. Each action re-checks, at click
/// time, that nothing using the cache is running, and asks first.
@MainActor
enum DiskActions {
    static func empty(_ items: [DiskStore.CacheItem], store: DiskStore, monitor: MonitorStore) async {
        guard monitor.report != nil else {
            store.lastActionMessage = "Still reading what's running. Try again in a moment."
            return
        }
        let running = runningNames(monitor)
        let (ready, busy) = split(items, running: running)
        guard !ready.isEmpty else {
            store.lastActionMessage = busy.first.map { "Kept \($0.target.title): \($0.target.blocker(running: running) ?? "") is running." }
            return
        }
        let bytes = ready.compactMap(\.bytes).reduce(0, +)
        let names = ready.map(\.target.title).joined(separator: ", ")
        guard Confirm.quit(title: ready.count == 1 ? "Empty \(names)?" : "Empty \(ready.count) developer caches?",
                           detail: "\(names). They rebuild themselves when needed. This deletes them for good (the Trash would keep the space used). Frees about \(Format.bytes(bytes)).",
                           actionTitle: "Empty and Free \(Format.bytes(bytes))") else { return }
        var freed: UInt64 = 0
        for item in ready {
            let path = item.target.path()
            let after = await Task.detached { _ = CachePurger.empty(path); return DiskSize.total(of: [path]) ?? 0 }.value
            freed += (item.bytes ?? 0) > after ? (item.bytes ?? 0) - after : 0
            store.setMeasured(item.target, bytes: after)
        }
        let kept = busy.isEmpty ? "" : " Kept \(busy.map(\.target.title).joined(separator: ", ")): in use."
        store.lastActionMessage = "Freed \(Format.bytes(freed)).\(kept)"
    }

    static func clearCaches(_ app: InstalledApp, store: DiskStore) async {
        store.refreshRunning()
        guard let current = store.apps.first(where: { $0.path == app.path }), !current.isRunning else {
            store.lastActionMessage = "Quit \(app.name) first: its caches are in use."
            return
        }
        guard Confirm.quit(title: "Clear \(app.name)'s caches?",
                           detail: "Only its cache folders. Settings, sign-ins and documents stay. It rebuilds them as it needs them.",
                           actionTitle: "Clear \(Format.bytes(current.cacheBytes ?? 0))") else { return }
        let paths = current.cachePaths
        let after = await Task.detached { paths.forEach { _ = CachePurger.empty($0) }; return DiskSize.total(of: paths) ?? 0 }.value
        let before = current.cacheBytes ?? 0
        store.setCaches(of: app.path, bytes: after)
        store.lastActionMessage = "Cleared \(app.name)'s caches, freeing \(Format.bytes(before > after ? before - after : 0))."
    }

    static func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    nonisolated static func split(_ items: [DiskStore.CacheItem], running: Set<String>) -> (ready: [DiskStore.CacheItem], busy: [DiskStore.CacheItem]) {
        (items.filter { $0.target.blocker(running: running) == nil }, items.filter { $0.target.blocker(running: running) != nil })
    }

    static func runningNames(_ monitor: MonitorStore) -> Set<String> {
        Set(monitor.report?.processes.map(\.snapshot.name) ?? [])
    }
}
