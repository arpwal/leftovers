import Testing
@testable import Leftovers

@Suite("System strength")
struct SystemStrengthTests {
    private let gib = Fixture.gib

    @Test func workedExample() {
        // 48 GB RAM, 16 GB available; 11 GB swap (limit = 12 GB); 1 TB disk, 100 GB free (healthy = 200 GB).
        let inputs = StrengthInputs(totalMemory: 48 * gib, availableMemory: 16 * gib, swapUsed: 11 * gib,
                                    diskTotal: 1000 * gib, diskFree: 100 * gib)
        let parts = SystemStrength.parts(inputs)
        #expect(abs(parts.memory - 1.0 / 3) < 0.001)
        #expect(abs(parts.swap - 1.0 / 12) < 0.001)
        #expect(abs(parts.disk - 0.5) < 0.001)
        #expect(SystemStrength.score(inputs) == 29)   // 0.5·0.333 + 0.3·0.083 + 0.2·0.5 = 0.2917
    }

    @Test func cleanupFreesRAMReleasesSwapAndFreesDisk() {
        let inputs = StrengthInputs(totalMemory: 48 * gib, availableMemory: 16 * gib, swapUsed: 11 * gib,
                                    diskTotal: 1000 * gib, diskFree: 100 * gib,
                                    reclaimableResident: 2 * gib, reclaimableSwapped: 8 * gib, reclaimableDisk: 60 * gib)
        let after = SystemStrength.afterCleanup(inputs)
        #expect(after.availableMemory == 18 * gib && after.swapUsed == 3 * gib && after.diskFree == 160 * gib)
        #expect(SystemStrength.score(after) > SystemStrength.score(inputs))
    }

    @Test func nothingToCleanMeansNoChange() {
        let inputs = StrengthInputs(totalMemory: 16 * gib, availableMemory: 8 * gib, swapUsed: 0,
                                    diskTotal: 500 * gib, diskFree: 250 * gib)
        #expect(SystemStrength.score(SystemStrength.afterCleanup(inputs)) == SystemStrength.score(inputs))
        #expect(SystemStrength.score(inputs) == 75)   // 0.5·0.5 + 0.3·1 + 0.2·1
    }

    @Test func staysWithinZeroToHundredAtTheExtremes() {
        let best = StrengthInputs(totalMemory: 8 * gib, availableMemory: 8 * gib, swapUsed: 0, diskTotal: 100 * gib, diskFree: 100 * gib)
        let worst = StrengthInputs(totalMemory: 8 * gib, availableMemory: 0, swapUsed: 64 * gib, diskTotal: 100 * gib, diskFree: 0)
        let unknownDisk = StrengthInputs(totalMemory: 8 * gib, availableMemory: 4 * gib, swapUsed: 0, diskTotal: 0, diskFree: 0)
        #expect(SystemStrength.score(best) == 100)
        #expect(SystemStrength.score(worst) == 0)
        #expect((0...100).contains(SystemStrength.score(unknownDisk)))
        // Reclaiming more than exists never overflows or goes past the totals.
        var over = worst; over.reclaimableSwapped = 100 * gib; over.reclaimableResident = 100 * gib; over.reclaimableDisk = 500 * gib
        let after = SystemStrength.afterCleanup(over)
        #expect(after.swapUsed == 0 && after.availableMemory == 8 * gib && after.diskFree == 100 * gib)
    }
}
