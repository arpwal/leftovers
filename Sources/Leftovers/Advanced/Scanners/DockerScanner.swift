import Foundation

/// What Docker could give back, from `docker system df`. Needs Docker (or
/// OrbStack, Colima) running; volumes are shown but never offered.
enum DockerScanner {
    static let candidates = ["/opt/homebrew/bin/docker", "/usr/local/bin/docker",
                             NSHomeDirectory() + "/.docker/bin/docker", NSHomeDirectory() + "/.orbstack/bin/docker",
                             "/Applications/Docker.app/Contents/Resources/bin/docker"]

    static var binary: String? { candidates.first(where: FileManager.default.isExecutableFile(atPath:)) }

    static func scan() -> ToolReport {
        guard let docker = binary else { return ToolReport(items: [], notice: "Docker isn't installed.") }
        guard let out = Git.run(executable: docker, ["system", "df", "--format", "{{json .}}"], timeout: 20) else {
            return ToolReport(items: [], notice: "Docker isn't running. Start Docker to see what it's keeping.")
        }
        return ToolReport(items: items(fromSystemDF: out))
    }

    struct Row: Decodable {
        let type: String, totalCount: String, active: String, size: String, reclaimable: String
        enum CodingKeys: String, CodingKey {
            case type = "Type", totalCount = "TotalCount", active = "Active", size = "Size", reclaimable = "Reclaimable"
        }
    }

    /// Pure: one JSON object per line, as `docker system df --format '{{json .}}'` prints.
    static func items(fromSystemDF text: String) -> [CleanableItem] {
        text.split(separator: "\n").compactMap { try? JSONDecoder().decode(Row.self, from: Data($0.utf8)) }.compactMap(item)
    }

    private static func item(_ row: Row) -> CleanableItem? {
        let reclaimable = HumanBytes.parse(row.reclaimable)
        let total = "\(row.totalCount) total, \(row.active) in use"
        switch row.type {
        case "Images":
            return CleanableItem(id: "docker:images", title: "Unused images", detail: "\(total). Pulled again when needed.",
                                 bytes: reclaimable, removal: .docker(.unusedImages))
        case "Containers":
            return CleanableItem(id: "docker:containers", title: "Stopped containers", detail: "\(total). Running ones are kept.",
                                 bytes: reclaimable, removal: .docker(.stoppedContainers))
        case "Build Cache":
            return CleanableItem(id: "docker:build", title: "Build cache", detail: "Rebuilt on the next build.",
                                 bytes: reclaimable, removal: .docker(.buildCache))
        case "Local Volumes":
            return CleanableItem(id: "docker:volumes", title: "Volumes (kept)", detail: "\(total). They can hold databases, so Leftovers never removes them.",
                                 bytes: HumanBytes.parse(row.size))
        default: return nil
        }
    }
}
