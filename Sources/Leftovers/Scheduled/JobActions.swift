import AppKit

/// What you can do to a job. Pausing unloads it (the file stays); removing
/// unloads it and moves its file to the Trash, so both can be undone.
@MainActor
enum JobActions {
    static func runNow(_ job: ScheduledJob) -> String {
        Launchctl.run(["kickstart", "\(Launchctl.domain)/\(job.label)"]) != nil
            ? "Started \(job.title)" : "Couldn't start \(job.title). Is it paused?"
    }

    static func pause(_ job: ScheduledJob) -> String {
        Launchctl.run(["bootout", "\(Launchctl.domain)/\(job.label)"])
        return "Paused \(job.title). It won't run until you resume it."
    }

    static func resume(_ job: ScheduledJob) -> String {
        Launchctl.run(["bootstrap", Launchctl.domain, job.plistPath]) != nil
            ? "Resumed \(job.title)" : "Couldn't resume \(job.title)"
    }

    static func remove(_ job: ScheduledJob) async -> String {
        if job.isLoaded { Launchctl.run(["bootout", "\(Launchctl.domain)/\(job.label)"]) }
        do {
            try await NSWorkspace.shared.recycle([URL(fileURLWithPath: job.plistPath)])
            return "Moved \(job.title) to the Trash"
        } catch {
            return "Couldn't remove \(job.title): \(error.localizedDescription)"
        }
    }

    static func showLog(_ job: ScheduledJob) {
        guard let log = job.logPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: log))
    }

    static func revealFile(_ job: ScheduledJob) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: job.plistPath)])
    }
}

/// Confirmation for actions with side effects.
@MainActor
enum JobConfirm {
    static func runNow(_ job: ScheduledJob) -> Bool {
        Confirm.quit(title: "Run \(job.title) now?", detail: "It runs \(job.program) immediately, outside its schedule.",
                     actionTitle: "Run Now")
    }

    static func pause(_ job: ScheduledJob) -> Bool {
        Confirm.quit(title: "Pause \(job.title)?", detail: "It stops running on schedule until you resume it. Nothing is deleted.",
                     actionTitle: "Pause")
    }

    static func remove(_ job: ScheduledJob) -> Bool {
        Confirm.quit(title: "Remove \(job.title)?", detail: "It stops, and its file goes to the Trash, so you can put it back.",
                     actionTitle: "Move to Trash")
    }
}
