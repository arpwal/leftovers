import Testing
@testable import Leftovers

@Suite("Command routing")
struct CommandRouterTests {
    private func route(_ args: String...) -> CommandRouter.Command {
        CommandRouter.command(for: ["Leftovers"] + args)
    }

    @Test func modifiersGoToTheirCommand() {
        #expect(route("--worktrees", "--json") == .worktrees(json: true))   // was hijacked by the memory report
        #expect(route("--json", "--worktrees") == .worktrees(json: true))   // order doesn't matter
        #expect(route("--jobs", "--json") == .jobs(json: true))
        #expect(route("--jobs") == .jobs(json: false))
        #expect(route("--check-updates", "--install") == .checkUpdates(install: true))
        #expect(route("--json") == .memoryJSON)
        #expect(route("--report") == .memoryReport)
        #expect(route("--clean") == .clean)
    }

    @Test func helpUnknownAndMissingValues() {
        #expect(route("--help") == .help)
        #expect(route("-h", "--jobs") == .help)
        #expect(route("--bogus") == .unknown("--bogus"))
        #expect(route("--snapshot") == .missingValue("--snapshot"))
        #expect(route("--snapshot", "--redact") == .missingValue("--snapshot"))
        #expect(route("--snapshot", "/tmp/shots", "--redact") == .snapshot(directory: "/tmp/shots", redact: true))
    }

    @Test func noCommandOrLaunchArgumentsStartTheApp() {
        #expect(route() == .app)
        #expect(route("-psn_0_12345") == .app)                                  // added by Finder
        #expect(route("-NSDocumentRevisionsDebugMode", "YES") == .app)          // added by Xcode
    }
}
