import SwiftUI

/// "What's holding your Mac back": each row says what and how much, and
/// takes you to the section where you can deal with it.
struct HoldingBackList: View {
    let model: OverviewModel
    let open: (DashboardSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("What's holding your Mac back").font(.headline).padding(.bottom, 6)
            row("drop.triangle", "Likely leaks", detail: count(model.leakCount, "process", "processes"),
                value: Format.bytes(model.leakBytes) + " memory", section: .leaks)
            row("arrow.triangle.branch", "Worktrees already on main", detail: count(model.safeWorktreeCount, "worktree", "worktrees"),
                value: model.worktreesMeasured ? Format.bytes(model.worktreeBytes) + " disk" : "measuring…", section: .worktrees)
            row("shippingbox", "Developer caches", detail: "rebuild themselves when needed",
                value: model.cachesMeasured ? Format.bytes(model.cacheBytes) + " disk" : "measuring…", section: .disk)
            row("square.on.square", "Duplicate MCP servers", detail: count(model.duplicateServerCount, "copy", "copies"),
                value: Format.bytes(model.duplicateServerBytes) + " memory", section: .agents)
            row("clock.badge.exclamationmark", "Failing scheduled jobs", detail: count(model.failingJobs, "job", "jobs"),
                value: model.failingJobs == 0 ? "none" : "check them", section: .scheduled)
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ symbol: String, _ title: String, detail: String, value: String, section: DashboardSection) -> some View {
        Button { open(section) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 20).foregroundStyle(Palette.emerald600)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(value).monospacedDigit().foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
}
