import Foundation

/// How an item is removed. Every case is something that comes back on its
/// own or with one download/install; nothing here holds your work.
enum Removal: Codable, Hashable {
    /// Delete this folder (validated: a real folder inside the home folder).
    case folder(String)
    /// An Ollama model: its manifest plus the blobs no other model shares.
    case ollamaModel(name: String, manifest: String, root: String)
    case docker(DockerPrune)
    case simulatorDevice(udid: String)
    case simulatorRuntime(id: String)
    /// A local Time Machine snapshot, by its date (macOS asks for your password).
    case timeMachineSnapshot(date: String)
}

enum DockerPrune: String, Codable, Hashable {
    case unusedImages, stoppedContainers, buildCache

    var arguments: [String] {
        switch self {
        case .unusedImages: return ["image", "prune", "--all", "--force"]
        case .stoppedContainers: return ["container", "prune", "--force"]
        case .buildCache: return ["builder", "prune", "--all", "--force"]
        }
    }
}

/// One row in an Advanced section.
struct CleanableItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    var bytes: UInt64?
    var lastUsed: Date?
    /// nil: shown for information only.
    var removal: Removal?
    /// Folder whose size is measured after the scan (progressively).
    var measurePath: String?
    /// Why it can't be removed right now ("Booted", "In use by node").
    var blocker: String?

    var canRemove: Bool { removal != nil && blocker == nil }
    var sortTitle: String { title.lowercased() }
    var sortBytes: UInt64 { bytes ?? 0 }
    var sortLastUsed: Date { lastUsed ?? .distantPast }
}

/// What one scan of a tool found.
struct ToolReport: Codable {
    var items: [CleanableItem]
    /// Shown above the table ("Docker isn't running").
    var notice: String?
    var scannedAt = Date()
}
