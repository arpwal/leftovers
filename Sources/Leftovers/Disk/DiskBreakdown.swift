import Foundation

/// Which side of the Mac a slice of disk belongs to.
enum DiskOwner: String, CaseIterable {
    case system = "System"
    case apps = "Apps"
    case yours = "Yours"
}

/// One slice of the disk bar.
enum DiskArea: String, CaseIterable, Identifiable {
    case macOS = "macOS"
    case systemSupport = "Swap, updates and recovery"
    case apps = "Apps"
    case appData = "App data"
    case other = "Your files and everything else"
    case free = "Free"

    var id: String { rawValue }

    var owner: DiskOwner? {
        switch self {
        case .macOS, .systemSupport: return .system
        case .apps, .appData: return .apps
        case .other: return .yours
        case .free: return nil
        }
    }
}

/// Raw numbers from the APFS container holding the boot volume, in bytes.
struct VolumeUsage: Equatable {
    var containerTotal: UInt64
    var containerFree: UInt64
    /// The sealed macOS volume.
    var system: UInt64
    /// Preboot, Recovery, Update and VM (swap) volumes.
    var systemSupport: UInt64
    /// The Data volume: apps, their data, your files, system data.
    var data: UInt64
}

/// The disk split into system, app and personal use. Apps and app data are
/// measured; "your files and everything else" is what's left of the Data
/// volume, so the slices always add up to the container.
struct DiskBreakdown: Equatable {
    let volumes: VolumeUsage
    var appBytes: UInt64 = 0
    var appDataBytes: UInt64 = 0

    func bytes(_ area: DiskArea) -> UInt64 {
        switch area {
        case .macOS: return volumes.system
        case .systemSupport: return volumes.systemSupport
        case .apps: return appBytes
        case .appData: return appDataBytes
        case .other:
            let measured = appBytes + appDataBytes
            return volumes.data > measured ? volumes.data - measured : 0
        case .free: return volumes.containerFree
        }
    }

    func bytes(_ owner: DiskOwner) -> UInt64 {
        DiskArea.allCases.filter { $0.owner == owner }.reduce(0) { $0 + bytes($1) }
    }
}
