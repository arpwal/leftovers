import SwiftUI

/// Every app you installed with what it really costs: the app itself, its
/// support data and its caches. Caches can be cleared while the app is quit.
struct DiskAppsTable: View {
    @ObservedObject var store: DiskStore
    @State private var selection = Set<InstalledApp.ID>()
    @State private var sortOrder = [KeyPathComparator(\InstalledApp.totalBytes, order: .reverse)]

    var body: some View {
        if store.apps.isEmpty {
            if store.progress.isScanning { SkeletonRows() }
            else { ContentUnavailableView("No Apps Found", systemImage: "square.grid.2x2") }
        } else {
            table
        }
    }

    private var table: some View {
        Table(store.apps.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("App", value: \.sortName) { app in
                HStack(spacing: 8) {
                    Image(nsImage: AppIconProvider.icon(atPath: app.path)).resizable().frame(width: 18, height: 18)
                    Text(app.name).lineLimit(1)
                    if app.isRunning { Text("Open").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .width(min: 160, ideal: 240)
            TableColumn("App", value: \.sortApp) { size($0.appBytes) }.width(min: 60, ideal: 80)
            TableColumn("Data", value: \.sortData) { size($0.dataBytes) }.width(min: 60, ideal: 80)
            TableColumn("Caches", value: \.sortCaches) { size($0.cacheBytes) }.width(min: 60, ideal: 80)
            TableColumn("Total", value: \.totalBytes) { app in size(app.isMeasured ? app.totalBytes : nil).fontWeight(.medium) }
                .width(min: 60, ideal: 90)
            TableColumn("") { app in
                if app.canClearCaches { Button("Clear Caches") { clear(app) }.controlSize(.small) }
            }
            .width(min: 90, ideal: 100)
        }
        .contextMenu(forSelectionType: InstalledApp.ID.self) { ids in
            if let app = store.apps.first(where: { ids.contains($0.id) }) {
                Button("Show in Finder") { DiskActions.reveal(app.path) }
                ForEach(app.dataPaths + app.cachePaths, id: \.self) { path in
                    Button("Show \((path as NSString).deletingLastPathComponent.split(separator: "/").last ?? "") Folder") { DiskActions.reveal(path) }
                }
                if app.canClearCaches { Divider(); Button("Clear Caches…") { clear(app) } }
            }
        } primaryAction: { ids in
            store.apps.filter { ids.contains($0.id) }.forEach { DiskActions.reveal($0.path) }
        }
    }

    private func size(_ bytes: UInt64?) -> Text {
        Text(bytes.map(Format.bytes) ?? "…").monospacedDigit()
    }

    private func clear(_ app: InstalledApp) { Task { await DiskActions.clearCaches(app, store: store) } }
}
