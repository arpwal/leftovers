import Foundation

/// macOS's own memory-pressure level (`kern.memorystatus_vm_pressure_level`).
enum MemoryPressure: Int32 {
    case normal = 1
    case warning = 2
    case critical = 4

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

/// Whole-machine memory figures.
struct SystemMemory: Hashable {
    let totalBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64
    let compressedBytes: UInt64
    /// Percent of memory macOS considers available (`kern.memorystatus_level`).
    let availablePercent: Int
    let pressure: MemoryPressure

    var swapFraction: Double {
        swapTotalBytes == 0 ? 0 : Double(swapUsedBytes) / Double(swapTotalBytes)
    }
}
