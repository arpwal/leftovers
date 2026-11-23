import Foundation

/// fseventsd judged against its limits. CPU must stay over the limit for
/// the whole window; memory needs only one reading (it never drops by itself).
struct FseventsdHealth: Equatable, Sendable {
    let reading: FseventsdReading
    let limits: FseventsdLimits
    let sustainedCpu: Bool
    /// How long CPU has been over the limit so far (0 when under it).
    let cpuOverFor: TimeInterval

    var overMemory: Bool { reading.memoryBytes > limits.memoryBytes }
    var overCpuNow: Bool { (reading.cpuPercent ?? 0) > limits.cpuPercent }
    var needsRestart: Bool { sustainedCpu || overMemory }

    init(reading: FseventsdReading, limits: FseventsdLimits, window: CpuWindow) {
        self.reading = reading
        self.limits = limits
        sustainedCpu = window.isSustained(above: limits.cpuPercent, for: limits.sustainedFor)
        cpuOverFor = window.timeAbove(limits.cpuPercent)
    }

    /// "20 GB memory (limit 50 MB) and 118% CPU for 2m".
    var reason: String {
        var parts: [String] = []
        if overMemory { parts.append("\(Format.bytes(reading.memoryBytes)) memory (limit \(Format.bytes(limits.memoryBytes)))") }
        if sustainedCpu { parts.append("\(Format.cpu(reading.cpuPercent)) CPU for \(Format.age(cpuOverFor))") }
        return parts.isEmpty ? "within limits" : parts.joined(separator: " and ")
    }

    /// "20 GB · 118% CPU".
    var usage: String { "\(Format.bytes(reading.memoryBytes)) · \(Format.cpu(reading.cpuPercent)) CPU" }
}
