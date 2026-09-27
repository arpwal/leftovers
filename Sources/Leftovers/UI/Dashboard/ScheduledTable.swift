import SwiftUI

/// Background jobs (LaunchAgents) in the user's account, with the ones
/// Claude created labelled. Refreshes every few seconds while visible.
struct ScheduledTable: View {
    @ObservedObject var store: ScheduledStore
    @State private var selection = Set<ScheduledJob.ID>()
    @State private var sortOrder = [KeyPathComparator(\ScheduledJob.sortNextRun)]

    var body: some View {
        Group {
            if !store.hasLoaded {
                LoadingState(text: "Reading scheduled jobs…")
            } else if store.jobs.isEmpty {
                ContentUnavailableView("No Scheduled Jobs", systemImage: "clock",
                                       description: Text("Background jobs in ~/Library/LaunchAgents show up here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                table
            }
        }
        .task {
            while !Task.isCancelled {
                await store.reload()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private var table: some View {
        Table(store.jobs.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Job", value: \.sortTitle) { JobTitleCell(job: $0) }.width(min: 180, ideal: 300)
            TableColumn("Schedule") { Text(JobScheduleText.describe($0.schedule)).lineLimit(1) }.width(min: 90, ideal: 150)
            TableColumn("Next run", value: \.sortNextRun) { job in
                Text(JobScheduleText.nextRun(job.schedule, lastRun: job.lastActivity).map { $0.formatted(.relative(presentation: .named)) } ?? "—")
                    .foregroundStyle(job.isLoaded ? .primary : .secondary).lineLimit(1)
            }
            .width(min: 70, ideal: 110)
            TableColumn("Status", value: \.sortStatus) { JobStatusBadge(job: $0) }.width(min: 70, ideal: 90)
            TableColumn("") { job in
                Button(job.isLoaded ? "Pause" : "Resume") { toggle(job) }.controlSize(.small)
            }
            .width(min: 64, ideal: 70)
        }
        .contextMenu(forSelectionType: ScheduledJob.ID.self) { ids in
            if let job = store.jobs.first(where: { ids.contains($0.id) }) { menu(job) }
        } primaryAction: { ids in
            store.jobs.filter { ids.contains($0.id) }.forEach(JobActions.showLog)
        }
    }

    @ViewBuilder private func menu(_ job: ScheduledJob) -> some View {
        Button("Run Now…") { if JobConfirm.runNow(job) { Task { await store.perform(JobActions.runNow(job)) } } }
            .disabled(!job.isLoaded)
        Button(job.isLoaded ? "Pause…" : "Resume") { toggle(job) }
        Divider()
        Button("Show Log") { JobActions.showLog(job) }.disabled(job.logPath == nil)
        Button("Show in Finder") { JobActions.revealFile(job) }
        Divider()
        Button("Remove…") { if JobConfirm.remove(job) { Task { await store.perform(await JobActions.remove(job)) } } }
    }

    private func toggle(_ job: ScheduledJob) {
        if job.isLoaded {
            guard JobConfirm.pause(job) else { return }
            Task { await store.perform(JobActions.pause(job)) }
        } else {
            Task { await store.perform(JobActions.resume(job)) }
        }
    }
}
