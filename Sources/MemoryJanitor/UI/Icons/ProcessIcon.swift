import SwiftUI

/// A process's app logo at a given size.
struct ProcessIcon: View {
    let snapshot: ProcessSnapshot
    var side: CGFloat = 20

    var body: some View {
        Image(nsImage: AppIconProvider.icon(for: snapshot))
            .resizable()
            .interpolation(.high)
            .frame(width: side, height: side)
    }
}

/// An agent's logo: its companion desktop app's icon, else a terminal symbol.
struct AgentIcon: View {
    let kind: AgentKind
    var side: CGFloat = 20

    var body: some View {
        if let image = AppIconProvider.icon(for: kind) {
            Image(nsImage: image).resizable().interpolation(.high).frame(width: side, height: side)
        } else {
            Image(systemName: "terminal")
                .font(.system(size: side * 0.6))
                .frame(width: side, height: side)
                .foregroundStyle(.secondary)
        }
    }
}
