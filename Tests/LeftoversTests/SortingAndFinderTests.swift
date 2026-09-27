import Foundation
import Testing
@testable import Leftovers

@Suite("Sorting and repository finding")
struct SortingAndFinderTests {
    @Test func processesSortByEachColumn() {
        let small = ClassifiedProcess(snapshot: Fixture.process(pid: 1, name: "b", footprint: 10), cpuPercent: 5, verdict: .normal)
        let big = ClassifiedProcess(snapshot: Fixture.process(pid: 2, name: "a", footprint: 90), cpuPercent: nil, verdict: .normal)
        #expect([small, big].sorted(using: KeyPathComparator(\ClassifiedProcess.sortMemory, order: .reverse)).map(\.snapshot.pid) == [2, 1])
        #expect([small, big].sorted(using: KeyPathComparator(\ClassifiedProcess.sortName)).map(\.snapshot.pid) == [2, 1])
        #expect([small, big].sorted(using: KeyPathComparator(\ClassifiedProcess.sortCPU, order: .reverse)).map(\.snapshot.pid) == [1, 2])
    }

    @Test func onlyUniqueFoldersOutsideKnownReposNeedAGitCall() {
        let home = "/Users/me"
        let folders = RepoFinder.candidateFolders(
            ["/Users/me", "/Users/me/code/app/src", "/Users/me/code/app/src", "/Users/me/other/x", "/tmp", "/Users/me/code/app"],
            knownRepositories: ["/Users/me/code/app"], home: home)
        #expect(folders == ["/Users/me/other/x"])
    }
}
