import Foundation

/// Reads a root process's memory and CPU time through the setuid system
/// tools (`/bin/ps`, `/usr/bin/top`), and parses their output.
enum FseventsdStatsReader {
    struct PsStats: Equatable {
        let residentBytes: UInt64
        let cpuSeconds: Double
    }

    /// Resident size and cumulative CPU time; ~3 ms.
    static func psStats(pid: pid_t) -> PsStats? {
        guard let out = Git.run(executable: "/bin/ps", ["-o", "rss=,cputime=", "-p", "\(pid)"], timeout: 5) else { return nil }
        return parsePs(out)
    }

    /// Footprint (top's MEM column). top samples every process, ~0.5 s.
    static func footprint(pid: pid_t) -> UInt64? {
        let arguments = ["-l", "1", "-pid", "\(pid)", "-stats", "pid,mem"]
        guard let out = Git.run(executable: "/usr/bin/top", arguments, timeout: 10) else { return nil }
        return parseTop(out, pid: pid)
    }

    /// "  8704   0:05.31" → 8704 KB, 5.31 s.
    static func parsePs(_ output: String) -> PsStats? {
        let fields = output.split(whereSeparator: \.isWhitespace)
        guard fields.count >= 2, let kilobytes = UInt64(fields[0]), let cpu = parseCpuTime(String(fields[1])) else { return nil }
        return PsStats(residentBytes: kilobytes * 1024, cpuSeconds: cpu)
    }

    /// "[[dd-]hh:]mm:ss.cc" → seconds.
    static func parseCpuTime(_ text: String) -> Double? {
        let dayParts = text.split(separator: "-")
        let days = dayParts.count == 2 ? Double(dayParts[0]) : 0
        guard let days, let clock = dayParts.last else { return nil }
        var seconds = 0.0
        for part in clock.split(separator: ":") {
            guard let value = Double(part) else { return nil }
            seconds = seconds * 60 + value
        }
        return days * 86_400 + seconds
    }

    /// The MEM value on the row for `pid`, e.g. "3792K", "20G", "1234M+".
    static func parseTop(_ output: String, pid: pid_t) -> UInt64? {
        let row = output.split(separator: "\n").reversed()
            .map { $0.split(whereSeparator: \.isWhitespace) }
            .first { $0.count >= 2 && $0[0] == "\(pid)" }
        return row.flatMap { parseSize(String($0[1])) }
    }

    static func parseSize(_ text: String) -> UInt64? {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        guard let unit = trimmed.last else { return nil }
        if let shift = binaryShift(unit), let value = Double(trimmed.dropLast()) {
            return UInt64(value * Double(UInt64(1) << shift))
        }
        return UInt64(trimmed)
    }

    /// top's size suffixes are binary: K = 2^10 … T = 2^40.
    private static func binaryShift(_ unit: Character) -> UInt64? {
        switch unit {
        case "B": return 0
        case "K": return 10
        case "M": return 20
        case "G": return 30
        case "T": return 40
        default: return nil
        }
    }
}
