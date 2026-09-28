import Foundation

/// Simulators whose runtime is gone (they can never boot again) and the
/// simulator runtimes themselves, from `xcrun simctl`.
enum SimulatorScanner {
    static func scan() -> ToolReport {
        guard let devices = Git.run(executable: "/usr/bin/xcrun", ["simctl", "list", "devices", "-j"], timeout: 30) else {
            return ToolReport(items: [], notice: "Xcode's simulator tools aren't installed.")
        }
        let runtimes = Git.run(executable: "/usr/bin/xcrun", ["simctl", "runtime", "list", "-j"], timeout: 30) ?? "{}"
        return ToolReport(items: items(devices: Data(devices.utf8), runtimes: Data(runtimes.utf8)))
    }

    struct Device: Decodable {
        let udid: String, name: String, state: String, isAvailable: Bool
        let dataPathSize: UInt64?
        let lastBootedAt: String?
    }

    struct Runtime: Decodable {
        let identifier: String, runtimeIdentifier: String, version: String
        let sizeBytes: UInt64?, lastUsedAt: String?, deletable: Bool?
    }

    private struct DeviceList: Decodable { let devices: [String: [Device]] }

    /// Pure: parses both `simctl` outputs.
    static func items(devices: Data, runtimes: Data) -> [CleanableItem] {
        let byRuntime = (try? JSONDecoder().decode(DeviceList.self, from: devices))?.devices ?? [:]
        let dead = byRuntime.flatMap { runtime, list in
            list.filter { !$0.isAvailable }.map { device in
                CleanableItem(id: "sim:" + device.udid, title: device.name,
                              detail: "\(runtimeName(runtime)), which is no longer installed. It can't start again.",
                              bytes: device.dataPathSize, lastUsed: device.lastBootedAt.flatMap(date),
                              removal: .simulatorDevice(udid: device.udid))
            }
        }
        let installed = ((try? JSONDecoder().decode([String: Runtime].self, from: runtimes)) ?? [:]).values.map { runtime in
            let users = byRuntime[runtime.runtimeIdentifier]?.filter(\.isAvailable) ?? []
            return CleanableItem(id: "rt:" + runtime.identifier, title: "\(runtimeName(runtime.runtimeIdentifier)) runtime",
                                 detail: users.isEmpty ? "No simulator uses it. Xcode downloads it again if needed."
                                     : "Used by \(users.count) simulator\(users.count == 1 ? "" : "s").",
                                 bytes: runtime.sizeBytes, lastUsed: runtime.lastUsedAt.flatMap(date),
                                 removal: runtime.deletable == false ? nil : .simulatorRuntime(id: runtime.identifier),
                                 blocker: users.isEmpty ? nil : "Kept: \(users.count) simulator\(users.count == 1 ? " uses" : "s use") it")
        }
        return dead.sorted { $0.title < $1.title } + installed.sorted { $0.title < $1.title }
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-18-6" → "iOS 18.6".
    static func runtimeName(_ identifier: String) -> String {
        let last = identifier.split(separator: ".").last.map(String.init) ?? identifier
        guard let dash = last.firstIndex(of: "-") else { return last }
        return last[..<dash] + " " + last[last.index(after: dash)...].replacingOccurrences(of: "-", with: ".")
    }

    static func date(_ text: String) -> Date? { ISO8601DateFormatter().date(from: text) }
}
