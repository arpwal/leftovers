import SwiftUI

/// First-launch welcome: three pages, one idea each.
/// Pages 1–2: "Start Using" skips ahead, "Continue" pages forward.
/// Page 3: "Continue" enters the app.
struct OnboardingView: View {
    @State private var page: OnboardingPage

    init(initialPage: OnboardingPage = .hiddenLeaks) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            OnboardingIllustration(page: page)
                .frame(height: 200)
                .id(page)
            Spacer(minLength: 28)
            VStack(spacing: 12) {
                Text(page.title).font(.system(size: 28, weight: .bold))
                Text(page.message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .id(page)
            .transition(.opacity.combined(with: .offset(y: 8)))
            Spacer(minLength: 32)
            PageDots(current: page)
            buttons.padding(.top, 24)
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 36)
        .frame(width: 580, height: 600)
        .tint(Palette.emerald500)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            if !page.isLast {
                Button("Start Using") { finish() }
                    .controlSize(.large)
            }
            Button("Continue") { advance() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func advance() {
        guard let next = page.next else { return finish() }
        withAnimation(.easeInOut(duration: 0.35)) { page = next }
    }

    private func finish() { WindowCoordinator.shared.finishWelcome() }
}

/// Current-page indicator.
private struct PageDots: View {
    let current: OnboardingPage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases) { page in
                Capsule()
                    .fill(page == current ? Palette.emerald500 : Color.secondary.opacity(0.3))
                    .frame(width: page == current ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
    }
}
