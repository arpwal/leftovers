import Foundation

/// Downloaded AI models: Ollama (sized from its manifests), Hugging Face's
/// hub cache and LM Studio (sized progressively by folder).
enum AIModelScanner {
    static func scan(home: String = NSHomeDirectory(), ollamaRoot: String = OllamaModels.defaultRoot) -> ToolReport {
        let items = ollama(root: ollamaRoot) + huggingFace(home: home) + lmStudio(home: home)
        return ToolReport(items: items, notice: items.isEmpty ? "No downloaded models found." : nil)
    }

    static func ollama(root: String) -> [CleanableItem] {
        OllamaModels.manifests(root: root).compactMap { entry in
            guard let manifest = OllamaModels.read(entry.path) else { return nil }
            return CleanableItem(id: "ollama:" + entry.name, title: entry.name, detail: "Ollama",
                                 bytes: manifest.blobs.reduce(0) { $0 + $1.size }, lastUsed: modified(entry.path),
                                 removal: .ollamaModel(name: entry.name, manifest: entry.path, root: root))
        }
    }

    static func huggingFace(home: String) -> [CleanableItem] {
        let hub = ProcessInfo.processInfo.environment["HF_HUB_CACHE"] ?? home + "/.cache/huggingface/hub"
        return children(hub).compactMap { name -> CleanableItem? in
            let parts = name.components(separatedBy: "--")
            guard parts.count >= 3, ["models", "datasets", "spaces"].contains(parts[0]) else { return nil }
            let path = hub + "/" + name
            let kind = parts[0] == "models" ? "Hugging Face model" : "Hugging Face \(parts[0].dropLast())"
            return folderItem(id: "hf:" + name, title: parts.dropFirst().joined(separator: "/"), detail: kind, path: path)
        }
    }

    static func lmStudio(home: String) -> [CleanableItem] {
        [home + "/.lmstudio/models", home + "/.cache/lm-studio/models"].flatMap { root in
            children(root).flatMap { publisher in
                children(root + "/" + publisher).map { model in
                    folderItem(id: "lms:\(root)/\(publisher)/\(model)", title: "\(publisher)/\(model)",
                               detail: "LM Studio", path: "\(root)/\(publisher)/\(model)")
                }
            }
        }
    }

    static func folderItem(id: String, title: String, detail: String, path: String) -> CleanableItem {
        CleanableItem(id: id, title: title, detail: detail, lastUsed: modified(path), removal: .folder(path), measurePath: path)
    }

    static func children(_ folder: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
    }

    static func modified(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }
}
