import Foundation
import Testing

/// The release script's version bump, run on a copy of the real script.
@Suite("Release scripts")
struct ReleaseScriptTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path

    private func bump(_ part: String, from version: String, build: Int) throws -> (String, String) {
        let dir = Fixture.temporaryDirectory()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try FileManager.default.createDirectory(atPath: "\(dir)/scripts", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(dir)/packaging", withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "\(Self.repoRoot)/scripts/bump-version.sh", toPath: "\(dir)/scripts/bump-version.sh")
        try "VERSION=\(version)\nBUILD=\(build)\nBUNDLE_ID=x\n".write(toFile: "\(dir)/packaging/release.env", atomically: true, encoding: .utf8)
        let printed = try Fixture.sh("scripts/bump-version.sh \(part)", in: dir).trimmingCharacters(in: .whitespacesAndNewlines)
        let env = try String(contentsOfFile: "\(dir)/packaging/release.env", encoding: .utf8)
        return (printed, env)
    }

    @Test func bumpsPatchMinorAndMajorAndTheBuildNumber() throws {
        let patch = try bump("patch", from: "1.3.0", build: 9)
        #expect(patch.0 == "1.3.1" && patch.1.contains("VERSION=1.3.1") && patch.1.contains("BUILD=10"))
        #expect(try bump("minor", from: "1.3.7", build: 9).0 == "1.4.0")
        #expect(try bump("major", from: "1.3.7", build: 9).0 == "2.0.0")
    }
}
