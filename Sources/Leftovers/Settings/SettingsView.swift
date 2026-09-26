import SwiftUI

/// Settings window (⌘,).
struct SettingsView: View {
    @ObservedObject var store: MonitorStore
    @AppStorage(SettingsKey.closeBehavior) private var closeBehavior: CloseBehavior = .keepInMenuBar
    @AppStorage(SettingsKey.refreshInterval) private var refreshInterval: RefreshInterval = .fiveSeconds
    @AppStorage(SettingsKey.showReclaimableInMenuBar) private var showReclaimable = true
    @State private var openAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("General") {
                Picker("When you close the window or press ⌘Q", selection: $closeBehavior) {
                    ForEach(CloseBehavior.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, enabled in loginError = LoginItem.setEnabled(enabled) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.secondary) }
                Toggle("Show reclaimable memory in the menu bar", isOn: $showReclaimable)
            }
            Section("Monitoring") {
                Picker("Refresh", selection: $refreshInterval) {
                    ForEach(RefreshInterval.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("Protected") { protectedList }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")
                Button("Show Welcome Again") { WindowCoordinator.shared.showWelcome() }
                Text("Leftovers makes no network requests. Everything it reads stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var protectedList: some View {
        if store.protectedNames.isEmpty {
            Text("Nothing yet. Use the lock button next to any process to keep it from being flagged or quit.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.protectedNames.sorted(), id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Button("Remove") { store.toggleProtection(for: name) }
                }
            }
        }
    }
}
