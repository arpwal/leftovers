import Foundation

/// Terminal entry points, so scripts and coding agents can use the same engine
/// and the same safety policy as the menu-bar app:
///   Leftovers --report    human-readable summary
///   Leftovers --json      machine-readable report (for agents)
///   Leftovers --clean     quit every likely leak; protected processes are never touched
enum CommandLineInterface {
    enum Command: String, CaseIterable {
        case report = "--report"
        case json = "--json"
        case clean = "--clean"
    }

    /// Gap between two samples, so CPU-based idleness is known.
    private static let sampleGap: Duration = .seconds(3)

    /// Runs a command and exits, or returns immediately to launch the UI.
    static func runIfRequested() {
        let arguments = Set(CommandLine.arguments.dropFirst())
        guard let command = Command.allCases.first(where: { arguments.contains($0.rawValue) }) else { return }
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await run(command)
            done.signal()
        }
        done.wait()
        exit(0)
    }

    private static func run(_ command: Command) async {
        let report = await takeReport()
        switch command {
        case .report: print(TextReport.render(report))
        case .json: print(JSONReport.render(report))
        case .clean: print(await CleanCommand.run(report))
        }
    }

    private static func takeReport() async -> MemoryReport {
        let engine = SampleEngine()
        let protectedNames = ProtectedNamesStore().load()
        _ = await engine.sample(protectedNames: protectedNames)
        try? await Task.sleep(for: sampleGap)
        return await engine.sample(protectedNames: protectedNames)
    }
}
