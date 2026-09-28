import Foundation

/// Reads Ollama's model store directly (no server needed): each model is a
/// manifest listing blobs by digest; blobs can be shared between models.
enum OllamaModels {
    struct Manifest: Decodable {
        struct Layer: Decodable { let digest: String; let size: UInt64 }
        let config: Layer?
        let layers: [Layer]
        var blobs: [Layer] { (config.map { [$0] } ?? []) + layers }
    }

    static var defaultRoot: String {
        ProcessInfo.processInfo.environment["OLLAMA_MODELS"] ?? NSHomeDirectory() + "/.ollama/models"
    }

    /// Every manifest file under `root/manifests`, with its model name.
    static func manifests(root: String) -> [(name: String, path: String)] {
        let base = root + "/manifests"
        guard let walker = FileManager.default.enumerator(atPath: base) else { return [] }
        return walker.compactMap { $0 as? String }.compactMap { relative in
            let parts = relative.split(separator: "/").map(String.init)
            guard parts.count == 4 else { return nil }   // registry/namespace/model/tag
            let path = base + "/" + relative
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
            return (name(parts), path)
        }
    }

    /// "llama3.2:3b", or "user/model:tag" outside the official library.
    static func name(_ parts: [String]) -> String {
        let model = parts[1] == "library" ? parts[2] : parts[1] + "/" + parts[2]
        return parts[0] == "registry.ollama.ai" ? "\(model):\(parts[3])" : "\(parts[0])/\(model):\(parts[3])"
    }

    static func read(_ path: String) -> Manifest? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    /// Blob files only this manifest uses: removing the model frees exactly these.
    static func unsharedBlobs(of manifest: String, root: String) -> [String] {
        guard let target = read(manifest) else { return [] }
        let others = manifests(root: root).filter { $0.path != manifest }.compactMap { read($0.path) }
        let shared = Set(others.flatMap { $0.blobs.map(\.digest) })
        return target.blobs.map(\.digest).filter { !shared.contains($0) }
            .map { root + "/blobs/" + $0.replacingOccurrences(of: ":", with: "-") }
    }
}
