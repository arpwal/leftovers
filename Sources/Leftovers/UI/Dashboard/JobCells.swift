import SwiftUI

/// Job name, what it runs, and an "Added by Claude" tag with its end date.
struct JobTitleCell: View {
    let job: ScheduledJob

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(job.title).fontWeight(.medium).lineLimit(1)
                if job.isFromClaude {
                    Text("Added by Claude").font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Palette.emerald500.opacity(0.15), in: Capsule())
                        .foregroundStyle(Palette.emerald600)
                }
            }
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                .help("\(job.label)\n\(job.program)")
        }
    }

    private var detail: String {
        guard let ends = job.metadata?.endsOn else { return job.program }
        return "\(job.program) · ends \(ends.formatted(date: .abbreviated, time: .omitted))"
    }
}

/// Running, waiting, paused, or failed at last run.
struct JobStatusBadge: View {
    let job: ScheduledJob

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).lineLimit(1)
        }
        .help(!job.isLoaded ? "Not loaded, so it won't run on its schedule. Resume turns it on."
              : job.lastExitStatus.map { "Last exit status: \($0)" } ?? "Hasn't run since it was loaded")
    }

    private var label: String {
        if !job.isLoaded { return "Off" }
        if job.isRunning { return "Running" }
        return job.hasFailed ? "Failed" : "Waiting"
    }

    private var color: Color {
        if !job.isLoaded { return .secondary }
        if job.isRunning { return Palette.emerald500 }
        return job.hasFailed ? Palette.red500 : Palette.emerald600.opacity(0.6)
    }
}
