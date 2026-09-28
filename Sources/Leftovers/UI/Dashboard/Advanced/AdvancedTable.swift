import SwiftUI

struct AdvancedTable: View {
    let items: [CleanableItem]
    @Binding var selection: Set<CleanableItem.ID>
    let remove: ([CleanableItem]) -> Void
    @State private var sortOrder = [KeyPathComparator(\CleanableItem.sortBytes, order: .reverse)]

    var body: some View {
        Table(items.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.sortTitle) { item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).fontWeight(.medium).lineLimit(1)
                    Text(item.blocker ?? item.detail).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).help(item.detail)
                }
            }
            .width(min: 200, ideal: 380)
            TableColumn("Last used", value: \.sortLastUsed) { item in
                Text(item.lastUsed.map { $0.formatted(.relative(presentation: .named)) } ?? "—").lineLimit(1)
            }
            .width(min: 80, ideal: 110)
            TableColumn("Size", value: \.sortBytes) { item in
                Text(item.bytes.map(Format.bytes) ?? (item.measurePath == nil ? "—" : "…")).monospacedDigit()
            }
            .width(min: 60, ideal: 80)
            TableColumn("") { item in
                if item.canRemove { Button("Remove") { remove([item]) }.controlSize(.small) }
            }
            .width(min: 70, ideal: 76)
        }
        .contextMenu(forSelectionType: CleanableItem.ID.self) { ids in
            let chosen = items.filter { ids.contains($0.id) }
            if let path = chosen.first.flatMap(folder) { Button("Show in Finder") { DiskActions.reveal(path) } }
            let removable = chosen.filter(\.canRemove)
            if !removable.isEmpty { Button(removable.count == 1 ? "Remove…" : "Remove \(removable.count)…") { remove(removable) } }
        }
    }

    private func folder(_ item: CleanableItem) -> String? {
        if case let .folder(path)? = item.removal { return path }
        return item.measurePath
    }
}
