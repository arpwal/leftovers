import Foundation

/// Why a process can never be killed from this app.
enum ProtectionReason: String {
    case selfProcess = "This app"
    case otherUser = "Owned by macOS or another user"
    case coreSystem = "Core macOS process"
    case systemBinary = "macOS system binary"
    case userProtected = "You marked it protected"
}

/// Why a process looks like leaked memory rather than useful work.
enum LeakReason: Hashable {
    /// Big footprint, almost all of it swapped/compressed, and doing nothing.
    case hoardingSwappedMemory(footprint: UInt64, resident: UInt64)
    /// A dev runtime whose terminal/app is gone (reparented to launchd).
    case detachedDevProcess(age: TimeInterval)
    /// Its working directory was deleted (e.g. a removed git worktree).
    case workingDirectoryDeleted(path: String)
    /// Very large footprint while idle for a long time.
    case largeWhileIdle(footprint: UInt64)

    var summary: String {
        switch self {
        case let .hoardingSwappedMemory(footprint, resident):
            return "Holding \(Format.bytes(footprint)) but only \(Format.bytes(resident)) in RAM, idle"
        case let .detachedDevProcess(age):
            return "Orphaned dev process, running \(Format.age(age)) with no terminal"
        case let .workingDirectoryDeleted(path):
            return "Its folder no longer exists: \(path)"
        case let .largeWhileIdle(footprint):
            return "Idle while holding \(Format.bytes(footprint))"
        }
    }
}

enum ProcessVerdict: Hashable {
    case protected(ProtectionReason)
    case suspect(LeakReason)
    case normal

    var isKillable: Bool {
        if case .protected = self { return false }
        return true
    }

    var isSuspect: Bool {
        if case .suspect = self { return true }
        return false
    }

    var explanation: String {
        switch self {
        case let .protected(reason): return reason.rawValue
        case let .suspect(reason): return reason.summary
        case .normal: return ""
        }
    }
}

/// A snapshot plus everything the UI needs to judge it.
struct ClassifiedProcess: Identifiable, Hashable {
    let snapshot: ProcessSnapshot
    /// nil on the first sample (no previous CPU reading to diff against).
    let cpuPercent: Double?
    let verdict: ProcessVerdict

    var id: ProcessIdentity { snapshot.identity }
}
