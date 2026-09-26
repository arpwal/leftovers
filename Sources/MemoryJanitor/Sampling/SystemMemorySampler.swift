import Darwin
import Foundation

/// Reads whole-machine memory figures from sysctl and the Mach VM statistics.
struct SystemMemorySampler {
    func sample() -> SystemMemory {
        let swap = Sysctl.read("vm.swapusage", initial: xsw_usage()) ?? xsw_usage()
        let pressureLevel = Sysctl.read("kern.memorystatus_vm_pressure_level", initial: Int32(1)) ?? 1
        return SystemMemory(
            totalBytes: Sysctl.read("hw.memsize", initial: UInt64(0)) ?? 0,
            swapUsedBytes: swap.xsu_used,
            swapTotalBytes: swap.xsu_total,
            compressedBytes: compressedBytes(),
            availablePercent: Int(Sysctl.read("kern.memorystatus_level", initial: Int32(0)) ?? 0),
            pressure: MemoryPressure(rawValue: pressureLevel) ?? .normal
        )
    }

    /// Physical memory occupied by the compressor.
    private func compressedBytes() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(Sysctl.read("hw.pagesize", initial: Int64(16_384)) ?? 16_384)
        return UInt64(stats.compressor_page_count) * pageSize
    }
}

/// Typed `sysctlbyname` reads.
enum Sysctl {
    static func read<Value: BitwiseCopyable>(_ name: String, initial: Value) -> Value? {
        var value = initial
        var size = MemoryLayout<Value>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
}
