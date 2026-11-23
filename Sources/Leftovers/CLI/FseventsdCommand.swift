import Foundation
import LeftoversHelperKit

/// `Leftovers --fseventsd [--json]`: fseventsd's memory and CPU against the
/// limits, where the reading came from, the helper, the backoff and the last
/// restart. Read-only; two readings 3 s apart so CPU% is known (the app's
/// sustained-CPU check needs 2 min, so here CPU is judged on this interval).
/// A reading that can't be taken is reported as unavailable, never as 0.
/// `Leftovers --restart-fseventsd [--force]`: restart it now, via the helper
/// if allowed, otherwise with macOS's administrator prompt. Respects the
/// cooldown and the cross-process restart lock; `--force` skips the cooldown.
enum FseventsdCommand {
    struct Output: Encodable {
        struct Limits: Encodable { let cpuPercent: Double; let memoryBytes: UInt64; let sustainedSeconds, cooldownSeconds: Double }
        struct Backoff: Encodable { let cooldownSeconds: Double; let quickRelapses: Int; let paused: Bool }
        struct Restart: Encodable {
            let date: Date; let trigger, method, result, detail: String
            let cpuPercentBefore: Double?; let memoryBytesBefore: UInt64?; let newPid: Int32?
        }
        /// running, notRunning or unavailable.
        let state: String
        let unavailableReason: String?
        let source: String?
        let pid: Int32?
        let path: String
        let startedAt: Date?
        let uptimeSeconds: Double?
        let cpuPercent: Double?
        let residentBytes: UInt64?
        let footprintBytes: UInt64?
        let memoryBytes: UInt64?
        let overCpu: Bool?
        let overMemory: Bool?
        let limits: Limits
        let backoff: Backoff
        let watching: Bool
        let autoRestart: Bool
        let helper: String
        let lastRestart: Restart?
    }

    private static let sampleGap: Duration = .seconds(3)

    static func runAndExit(json: Bool) {
        let output = blocking { await read() }
        print(json ? CLIJSON.encode(output) : text(output))
        exit(0)
    }

    static func restartAndExit(force: Bool) {
        let useHelper = PrivilegedHelper.status.isReady
        let before = blocking { () -> FseventsdReading? in
            if case let .reading(reading) = await FseventsdSampler().sample(useHelper: useHelper) { return reading }
            return nil
        }
        switch blocking({ await FseventsdRestarter.restart(trigger: .commandLine, before: before, force: force) }) {
        case let .failure(refusal):
            FileHandle.standardError.write(Data("Not restarted: \(refusal.message)\n".utf8))
            exit(1)
        case let .success(entry):
            let verb = entry.result == .forceKilled ? "Force-restarted" : entry.succeeded ? "Restarted" : "Couldn't restart"
            print("\(verb) fseventsd via \(entry.method.rawValue): \(entry.detail)")
            print(entry.newPid.map { "New fseventsd: pid \($0)" } ?? "No new fseventsd appeared within a minute")
            exit(entry.succeeded ? 0 : 1)
        }
    }

    private static func read() async -> Output {
        let sampler = FseventsdSampler()
        let useHelper = PrivilegedHelper.status.isReady
        _ = await sampler.sample(useHelper: useHelper)
        try? await Task.sleep(for: sampleGap)
        return output(for: await sampler.sample(useHelper: useHelper))
    }

    private static func output(for sample: FseventsdSampler.Sample) -> Output {
        let limits = AppSettings.fseventsdLimits
        let backoff = WatchdogStateStore().load(baseCooldown: limits.cooldown)
        var reading: FseventsdReading?
        var state = "notRunning", reason: String?
        switch sample {
        case .notRunning: break
        case let .unavailable(why): state = "unavailable"; reason = why
        case let .reading(r): state = "running"; reading = r
        }
        return Output(
            state: state, unavailableReason: reason, source: reading?.source.rawValue, pid: reading?.identity.pid,
            path: HelperConstants.fseventsdPath, startedAt: reading?.identity.startDate, uptimeSeconds: reading?.uptime,
            cpuPercent: reading?.cpuPercent, residentBytes: reading?.residentBytes, footprintBytes: reading?.footprintBytes,
            memoryBytes: reading?.memoryBytes,
            overCpu: reading.map { ($0.cpuPercent ?? 0) > limits.cpuPercent },
            overMemory: reading.map { $0.memoryBytes > limits.memoryBytes },
            limits: .init(cpuPercent: limits.cpuPercent, memoryBytes: limits.memoryBytes,
                          sustainedSeconds: limits.sustainedFor, cooldownSeconds: limits.cooldown),
            backoff: .init(cooldownSeconds: backoff.cooldown, quickRelapses: backoff.quickRelapses, paused: backoff.paused),
            watching: AppSettings.watchFseventsd, autoRestart: AppSettings.autoRestartFseventsd,
            helper: PrivilegedHelper.status.rawValue, lastRestart: FseventsdRestartLog().last.map(restart))
    }

    private static func restart(_ e: FseventsdRestartEntry) -> Output.Restart {
        Output.Restart(date: e.date, trigger: e.trigger.rawValue, method: e.method.rawValue, result: e.result.rawValue,
                       detail: e.detail, cpuPercentBefore: e.cpuPercentBefore, memoryBytesBefore: e.memoryBytesBefore,
                       newPid: e.newPid)
    }

    private static func text(_ o: Output) -> String {
        let footer = [
            "  Automatic restart: \(o.autoRestart ? "on" : "off")\(o.backoff.paused ? " (paused: it keeps relapsing)" : "") · helper: \(o.helper) · cooldown \(Format.age(o.backoff.cooldownSeconds))",
            "  Last restart: \(FseventsdRestartLog().last?.summary ?? "never")",
        ]
        switch o.state {
        case "notRunning": return (["fseventsd isn't running."] + footer).joined(separator: "\n")
        case "unavailable": return (["fseventsd (pid \(o.pid.map(String.init) ?? "?")): reading unavailable (\(o.unavailableReason ?? "unknown"))"] + footer).joined(separator: "\n")
        default: break
        }
        let flags = [o.overMemory == true ? "over memory limit" : nil, o.overCpu == true ? "over CPU limit" : nil].compactMap { $0 }
        return ([
            "fseventsd (pid \(o.pid ?? 0)), up \(Format.age(o.uptimeSeconds ?? 0)), read via \(o.source ?? "?")",
            "  Memory \(o.memoryBytes.map(Format.bytes) ?? "unavailable") (limit \(Format.bytes(o.limits.memoryBytes)))  CPU \(o.cpuPercent.map { Format.cpu($0) } ?? "unavailable") (limit \(Format.cpu(o.limits.cpuPercent)) for \(Format.age(o.limits.sustainedSeconds)))",
            "  Status: \(flags.isEmpty ? "within limits" : flags.joined(separator: ", "))",
        ] + footer).joined(separator: "\n")
    }

    /// Runs async work from the synchronous CLI entry point.
    private static func blocking<T>(_ work: @escaping @Sendable () async -> T) -> T {
        let done = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        Task.detached { box.value = await work(); done.signal() }
        done.wait()
        return box.value!
    }
}

private final class ResultBox<T>: @unchecked Sendable { var value: T? }

/// Pretty, sorted, ISO-8601 JSON, as the other commands print it.
enum CLIJSON {
    static func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}
