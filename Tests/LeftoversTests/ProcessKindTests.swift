import Testing
@testable import Leftovers

@Suite("Process kinds")
struct ProcessKindTests {
    @Test func desktopAppsAndTheirHelpers() {
        #expect(ProcessKind.classify(path: "/Applications/Slack.app/Contents/MacOS/Slack") == .appBundle)
        #expect(ProcessKind.classify(path: "/Applications/Slack.app/Contents/Frameworks/Slack Helper.app/Contents/MacOS/Slack Helper") == .appBundle)
    }

    @Test func frameworkPythonIsACommandLineToolNotAnApp() {
        let python = "/opt/homebrew/Cellar/python@3.14/3.14.0/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python"
        #expect(ProcessKind.classify(path: python) == .commandLine)
        #expect(AppBundle.outerPath(of: python) == nil)
    }

    @Test func xpcHelpersAndSystemBinaries() {
        let encoder = "/System/Library/Frameworks/VideoToolbox.framework/Versions/A/XPCServices/VTEncoderXPCService.xpc/Contents/MacOS/VTEncoderXPCService"
        #expect(ProcessKind.classify(path: encoder) == .xpcHelper)
        #expect(ProcessKind.isShippedWithMacOS(path: encoder))
        #expect(ProcessKind.classify(path: "/usr/libexec/trustd") == .systemBinary)
        #expect(ProcessKind.classify(path: "/opt/homebrew/bin/node") == .commandLine)
    }

    @Test func outerAppPathForHelpers() {
        #expect(AppBundle.outerPath(of: "/Applications/Slack.app/Contents/Frameworks/Slack Helper.app/Contents/MacOS/Slack Helper")
                == "/Applications/Slack.app")
    }
}
