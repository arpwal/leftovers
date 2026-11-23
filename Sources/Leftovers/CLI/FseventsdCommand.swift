import Foundation
import LeftoversHelperKit

/// `Leftovers --fseventsd [--json]`: fseventsd's memory and CPU against the
/// limits, the helper's state and the last restart. Read-only; two readings
/// 3 s apart so CPU% is known (the app's sustained-CPU check needs ~2 min
/// of readings, so here CPU is judged on this one interval).
/// `Leftovers --restart-fseventsd`: restart it now, via the helper if
/// approved, otherwise with macOS's administrator prompt.
enum FseventsdCommand {
    struct Output: Encodable {
        struct Limits: Encodable { let cpuPercent: Double; let memoryBytes: UInt64; let sustainedSeconds: Double }
        struct Restart: Encodable {
            let date: Date; let trigger, method, result, detail: String
            let cpuPercentBefore: Double?; let memoryBytesBefore: UInt64?
        }
        let running: Bool
        let pid: Int32?
        let path: String
        let startedAt: Date?
        let uptimeSeconds: Double?
        let cpuPercent: Double?
        let residentBytes: UInt64?
        let footprintBytes: UInt64?
        let memoryBytes: UInt64?
        let overCpu: Bool
        let overMemory: Bool
        let limits: Limits
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

    static func restartAndExit() {
        let before = blocking { await FseventsdSampler().sample() }
        guard let entry = blocking({ await FseventsdRestarter.restart(trigger: .commandLine, before: before) }) else { exit(1) }
        print("\(entry.succeeded ? "Restarted" : "Couldn't restart") fseventsd via \(entry.method.rawValue): \(entry.detail)")
        exit(entry.succeeded ? 0 : 1)
    }

    private static func read() async -> Output {
        let sampler = FseventsdSampler()
        _ = await sampler.sample()
        try? await Task.sleep(for: sampleGap)
        let reading = await sampler.sample()
        let limits = AppSettings.fseventsdLimits
        return Output(
            running: reading != nil, pid: reading?.identity.pid, path: HelperConstants.fseventsdPath,
            startedAt: reading?.identity.startDate, uptimeSeconds: reading?.uptime, cpuPercent: reading?.cpuPercent,
            residentBytes: reading?.residentBytes, footprintBytes: reading?.footprintBytes, memoryBytes: reading?.memoryBytes,
            overCpu: (reading?.cpuPercent ?? 0) > limits.cpuPercent, overMemory: (reading?.memoryBytes ?? 0) > limits.memoryBytes,
            limits: .init(cpuPercent: limits.cpuPercent, memoryBytes: limits.memoryBytes, sustainedSeconds: limits.sustainedFor),
            watching: AppSettings.watchFseventsd, autoRestart: AppSettings.autoRestartFseventsd,
            helper: PrivilegedHelper.status.rawValue, lastRestart: FseventsdRestartLog().last.map(restart))
    }

    private static func restart(_ e: FseventsdRestartEntry) -> Output.Restart {
        Output.Restart(date: e.date, trigger: e.trigger.rawValue, method: e.method.rawValue, result: e.result.rawValue,
                       detail: e.detail, cpuPercentBefore: e.cpuPercentBefore, memoryBytesBefore: e.memoryBytesBefore)
    }

    private static func text(_ o: Output) -> String {
        guard o.running, let memory = o.memoryBytes else { return "fseventsd isn't running." }
        let flags = [o.overMemory ? "over memory limit" : nil, o.overCpu ? "over CPU limit" : nil].compactMap { $0 }
        return [
            "fseventsd (pid \(o.pid ?? 0)), up \(Format.age(o.uptimeSeconds ?? 0))",
            "  Memory \(Format.bytes(memory)) (limit \(Format.bytes(o.limits.memoryBytes)))  CPU \(Format.cpu(o.cpuPercent)) (limit \(Format.cpu(o.limits.cpuPercent)) for \(Format.age(o.limits.sustainedSeconds)))",
            "  Status: \(flags.isEmpty ? "healthy" : flags.joined(separator: ", "))",
            "  Automatic restart: \(o.autoRestart ? "on" : "off") · helper: \(o.helper)",
            "  Last restart: \(FseventsdRestartLog().last?.summary ?? "never")",
        ].joined(separator: "\n")
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
