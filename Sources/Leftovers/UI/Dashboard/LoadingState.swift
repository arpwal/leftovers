import SwiftUI

/// A compact, centred "working on it" state used while a reading phase runs.
struct LoadingState: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// "812 processes · 41 ms": how fast the last reading was.
struct ScanSpeedLabel: View {
    let stats: ScanStats?

    var body: some View {
        if let stats {
            Label(stats.shortSummary, systemImage: "bolt.fill")
                .labelStyle(.titleAndIcon)
                .help(stats.summary)
                .monospacedDigit()
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Reading…")
            }
        }
    }
}
