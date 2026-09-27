import Foundation

/// Reads per-volume usage of the boot APFS container with `diskutil`.
/// The file-system APIs only report container-wide numbers, which can't tell
/// macOS apart from your data.
enum VolumeReader {
    static func read() -> VolumeUsage? {
        guard let info = plist(["info", "-plist", "/"]),
              let container = info["APFSContainerReference"] as? String,
              let list = plist(["apfs", "list", "-plist", container]),
              let containers = list["Containers"] as? [[String: Any]],
              let boot = containers.first(where: { $0["ContainerReference"] as? String == container }) else { return nil }
        return usage(from: boot)
    }

    /// Pure parsing of one container's dictionary, for tests.
    static func usage(from container: [String: Any]) -> VolumeUsage? {
        guard let total = number(container["CapacityCeiling"]), let free = number(container["CapacityFree"]),
              let volumes = container["Volumes"] as? [[String: Any]] else { return nil }
        var usage = VolumeUsage(containerTotal: total, containerFree: free, system: 0, systemSupport: 0, data: 0)
        for volume in volumes {
            let used = number(volume["CapacityInUse"]) ?? 0
            let roles = volume["Roles"] as? [String] ?? []
            if roles.contains("System") { usage.system += used }
            else if roles.contains("Data") { usage.data += used }
            else if roles.contains(where: supportRoles.contains) { usage.systemSupport += used }
        }
        return usage
    }

    private static let supportRoles: Set<String> = ["Preboot", "Recovery", "Update", "VM"]

    private static func number(_ value: Any?) -> UInt64? {
        (value as? NSNumber).map { $0.uint64Value }
    }

    private static func plist(_ arguments: [String]) -> [String: Any]? {
        guard let text = Git.run(executable: "/usr/sbin/diskutil", arguments, timeout: 10) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: Data(text.utf8), format: nil)) as? [String: Any]
    }
}
