import SwiftUI

/// Settings window (⌘,).
struct SettingsView: View {
    @ObservedObject var store: MonitorStore
    @AppStorage(SettingsKey.closeBehavior) private var closeBehavior: CloseBehavior = .keepInMenuBar
    @AppStorage(SettingsKey.refreshInterval) private var refreshInterval: RefreshInterval = .fiveSeconds
    @AppStorage(SettingsKey.showReclaimableInMenuBar) private var showReclaimable = true
    @AppStorage(SettingsKey.showInDock) private var showInDock = true
    @AppStorage(SettingsKey.notifyAboutUpdates) private var notifyAboutUpdates = true
    @AppStorage(SettingsKey.warnWhenDiskLow) private var warnWhenDiskLow = true
    @State private var openAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
    @State private var checksForUpdates = UpdateController.shared.automaticallyChecks

    var body: some View {
        Form {
            Section("General") {
                Picker("When you close the window or press ⌘Q", selection: $closeBehavior) {
                    ForEach(CloseBehavior.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, enabled in loginError = LoginItem.setEnabled(enabled) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.secondary) }
                Toggle("Show Leftovers in the Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, _ in
                        NSApp.setActivationPolicy(AppSettings.activationPolicy)
                        NSApp.activate() // keep Settings in front after the switch
                    }
                Toggle("Show reclaimable memory in the menu bar", isOn: $showReclaimable)
            }
            Section("Updates") { updatesSection }
            Section("Monitoring") {
                Picker("Refresh", selection: $refreshInterval) {
                    ForEach(RefreshInterval.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Warn me when the disk is almost full", isOn: $warnWhenDiskLow)
            }
            Section("Protected") { protectedList }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")
                Button("Show Welcome Again") { WindowCoordinator.shared.showWelcome() }
                LabeledContent("Free and open source") {
                    HStack {
                        Link("Star on GitHub", destination: AppLinks.repository)
                        Link("Follow @arpwal", destination: AppLinks.author)
                    }
                }
                Text("The only network request Leftovers makes is the update check. Everything it reads about your processes stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var updatesSection: some View {
        Toggle("Check for updates automatically", isOn: $checksForUpdates)
            .onChange(of: checksForUpdates) { _, enabled in UpdateController.shared.automaticallyChecks = enabled }
            .disabled(!UpdateController.shared.isAvailable)
        Toggle("Notify me when an update is ready", isOn: $notifyAboutUpdates)
        HStack {
            Button("Check for Updates…") { UpdateController.shared.checkForUpdates() }
                .disabled(!UpdateController.shared.isAvailable)
            Link("What's New", destination: AppLinks.changelog)
        }
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
