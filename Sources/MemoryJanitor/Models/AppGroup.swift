import Foundation

/// Every process belonging to one desktop app, e.g. Slack and its helpers.
struct AppGroup: Identifiable, Hashable {
    let bundlePath: String
    let name: String
    let processes: [ClassifiedProcess]

    var id: String { bundlePath }
    var totalFootprint: UInt64 { processes.reduce(0) { $0 + $1.snapshot.footprintBytes } }
    var totalCPU: Double { processes.compactMap(\.cpuPercent).reduce(0, +) }

    /// Groups processes by the `.app` they belong to, largest first.
    static func group(_ processes: [ClassifiedProcess]) -> [AppGroup] {
        let byBundle = Dictionary(grouping: processes.compactMap { process in
            AppBundle.outerPath(of: process.snapshot.executablePath).map { ($0, process) }
        }, by: \.0)
        return byBundle.map { path, pairs in
            AppGroup(bundlePath: path, name: AppBundle.displayName(atPath: path), processes: pairs.map(\.1))
        }
        .sorted { $0.totalFootprint > $1.totalFootprint }
    }
}
