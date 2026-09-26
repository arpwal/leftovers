import SwiftUI

/// The menu-bar item. It exists from launch (the menu itself does not), so it
/// also opens the welcome window the first time the app runs.
struct MenuBarLabel: View {
    let title: String
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
        Label { Text(title) } icon: { Image(nsImage: MenuBarGlyph.image) }
            .labelStyle(.titleAndIcon)
            .task {
                guard !hasCompletedOnboarding else { return }
                openWindow(id: MemoryJanitorApp.onboardingWindowID)
                NSApp.activate()
            }
    }
}
