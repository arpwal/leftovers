import Darwin
import Foundation

/// Builds a `ProcessSnapshot` for every process the kernel will describe.
struct ProcessSampler {
    func sample() -> [ProcessSnapshot] {
        LibProc.allPids().compactMap(snapshot(for:))
    }

    private func snapshot(for pid: pid_t) -> ProcessSnapshot? {
        guard let info = LibProc.bsdInfo(pid) else { return nil }
        let path = LibProc.executablePath(pid) ?? ""
        // rusage is nil for root-owned processes; they are protected anyway.
        let usage = LibProc.resourceUsage(pid)
        let cpuTicks = (usage?.ri_user_time ?? 0) + (usage?.ri_system_time ?? 0)

        return ProcessSnapshot(
            pid: pid,
            ppid: pid_t(info.pbi_ppid),
            uid: info.pbi_uid,
            name: displayName(info: info, path: path),
            executablePath: path,
            workingDirectory: LibProc.workingDirectory(pid),
            startDate: LibProc.startDate(info),
            footprintBytes: usage?.ri_phys_footprint ?? 0,
            residentBytes: usage?.ri_resident_size ?? 0,
            cpuTimeNanos: MachTime.nanoseconds(fromTicks: cpuTicks),
            kind: ProcessKind.classify(path: path)
        )
    }

    /// `pbi_name` holds up to 32 chars, `pbi_comm` only 16; the path is the fallback.
    private func displayName(info: proc_bsdinfo, path: String) -> String {
        let name = CString.decode(tuple: info.pbi_name)
        // Claude Code runs as `…/claude/versions/2.1.283`: name it, keep the version.
        if path.contains("/claude/versions/") { return "claude \(name)" }
        if !name.isEmpty { return name }
        let comm = CString.decode(tuple: info.pbi_comm)
        return comm.isEmpty ? (path as NSString).lastPathComponent : comm
    }
}
