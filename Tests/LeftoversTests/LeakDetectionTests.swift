import Darwin
import Foundation
import Testing
@testable import Leftovers

@Suite("Leak detection and protection")
struct LeakDetectionTests {
    private func detect(_ snapshot: ProcessSnapshot, cpu: Double? = 0, others: [ProcessSnapshot] = []) -> LeakReason? {
        LeakDetector(ancestry: AncestryIndex([snapshot] + others)).detect(snapshot, cpuPercent: cpu)
    }

    @Test func hoardingNeedsSizeSwapIdleAndAge() {
        let hoarder = Fixture.process(name: "helper", path: "/Applications/X.app/Contents/MacOS/helper", ageHours: 2,
                                      footprint: 3 * Fixture.gib, resident: 500 * Fixture.mib)
        #expect(detect(hoarder) == .hoardingSwappedMemory(footprint: 3 * Fixture.gib, resident: 500 * Fixture.mib))
        #expect(detect(hoarder, cpu: 5) == nil)            // busy
        #expect(detect(hoarder, cpu: nil) == nil)          // CPU unknown on first reading: stay silent
        let young = Fixture.process(ageHours: 0.2, footprint: 3 * Fixture.gib, resident: 500 * Fixture.mib)
        #expect(detect(young) == nil)                      // a busy build that just paged out
        let inRAM = Fixture.process(name: "helper", path: "/Applications/X.app/Contents/MacOS/helper", ageHours: 2,
                                    footprint: 3 * Fixture.gib, resident: 2 * Fixture.gib)
        #expect(detect(inRAM) == nil)                      // mostly in RAM: in use, not leaked
    }

    @Test func orphanedDevServerIsFlaggedOnlyWhenTheChainIsProvablyAbandoned() {
        let orphan = Fixture.process(pid: 10, ppid: 1, name: "node", ageHours: 13)
        if case .detachedDevProcess = detect(orphan) {} else { Issue.record("orphan not flagged: \(String(describing: detect(orphan)))") }

        let terminal = Fixture.process(pid: 20, ppid: 1, name: "iTerm2", path: "/Applications/iTerm.app/Contents/MacOS/iTerm2", ageHours: 48)
        let attached = Fixture.process(pid: 21, ppid: 20, name: "node", ageHours: 13)
        #expect(detect(attached, others: [terminal]) == nil)

        let unreadableParent = Fixture.process(pid: 30, ppid: 999, name: "node", ageHours: 13)
        #expect(detect(unreadableParent) == nil)            // can't see the parent: never over-flag

        let service = Fixture.process(pid: 40, ppid: 1, name: "postgres", path: "/opt/homebrew/bin/postgres", ageHours: 100)
        let child = Fixture.process(pid: 41, ppid: 40, name: "node", ageHours: 13)
        #expect(detect(child, others: [service]) == nil)   // launched on purpose by a service
    }

    @Test func deletedWorkingFolderIsFlaggedImmediately() {
        let lost = Fixture.process(name: "python3.11", cwd: "/tmp/definitely-deleted-\(UUID().uuidString)", ageHours: 0.1)
        #expect(detect(lost, cpu: 50) == .workingDirectoryDeleted(path: lost.workingDirectory!))
    }

    @Test func protectionAlwaysWins() {
        let policy = ProtectionPolicy(userProtectedNames: ["Figma"])
        #expect(policy.hardProtection(for: Fixture.process(uid: 0)) == .otherUser)
        #expect(policy.hardProtection(for: Fixture.process(name: "WindowServer")) == .coreSystem)
        #expect(policy.hardProtection(for: Fixture.process(name: "Figma")) == .userProtected)
        #expect(policy.hardProtection(for: Fixture.process(pid: getpid())) == .selfProcess)
        #expect(policy.hardProtection(for: Fixture.process()) == nil)
    }

    @Test func systemBinariesStayProtectedButHoardingXPCHelpersDoNot() {
        let classifier = ProcessClassifier(policy: ProtectionPolicy(userProtectedNames: []))
        let daemon = Fixture.process(pid: 50, name: "somehelperd", path: "/usr/libexec/somehelperd", ageHours: 5,
                                     footprint: 3 * Fixture.gib, resident: 100 * Fixture.mib)
        let encoder = Fixture.process(pid: 51, name: "VTEncoderXPCService",
                                      path: "/System/Library/Frameworks/VideoToolbox.framework/Versions/A/XPCServices/VTEncoderXPCService.xpc/Contents/MacOS/VTEncoderXPCService",
                                      ageHours: 96, footprint: 59 * Fixture.gib, resident: 7 * Fixture.mib)
        let verdicts = classifier.classify([daemon, encoder], cpu: [daemon.identity: 0, encoder.identity: 0])
        #expect(verdicts[0].verdict == .protected(.systemBinary))
        #expect(verdicts[1].verdict.isSuspect)
        #expect(verdicts[1].verdict.isKillable)
    }
}
