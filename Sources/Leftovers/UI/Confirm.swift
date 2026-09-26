import AppKit

/// Standard macOS confirmation alerts. The app is menu-bar only, so it must
/// come forward first or the alert opens behind other windows.
@MainActor
enum Confirm {
    static func quit(title: String, detail: String, actionTitle: String) -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func quit(_ process: ClassifiedProcess) -> Bool {
        let s = process.snapshot
        let detail = process.verdict.isSuspect ? process.verdict.explanation : "Any unsaved work in it will be lost."
        return quit(title: "Quit \(s.name)?", detail: detail, actionTitle: "Quit and free \(Format.bytes(s.footprintBytes))")
    }

    static func cleanUp(_ suspects: [ClassifiedProcess], freeing bytes: UInt64) -> Bool {
        let names = suspects.map(\.snapshot.name).joined(separator: ", ")
        return quit(title: "Quit \(suspects.count) likely leaks?", detail: names,
                    actionTitle: "Quit All and Free \(Format.bytes(bytes))")
    }
}
