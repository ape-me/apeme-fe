import SwiftUI

/// Signed in with no finished onboarding: the replay from You, or, with Ape mode on, the one
/// question that picks the mode.
struct OnboardingView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if Feature.ape, app.mode == nil { ModeQuestion() } else { WelcomeView(kind: .replay) }
    }
}

private struct ModeQuestion: View {
    @Environment(AppState.self) private var app
    @State private var choice: Mode? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("One question").font(.eyebrow).foregroundStyle(Theme.muted)
                Text("Have you traded memecoins before?").font(.system(size: 32, weight: .semibold)).tracking(-1.3)
            }
            option(.invest, "No, I invest", "Stocks first. Fair values, premiums, a calm view.")
            option(.ape, "Yes, I ape", "Floors first. New launches, kings, the live tape.")
            Text("Switch any time in You.").font(.sub).foregroundStyle(Theme.muted)
            Spacer()
            BigButton(label: "Get started", style: choice == nil ? .off : .white) {
                guard let choice else { return }
                app.mode = choice; app.onboarded = true; app.root(.home)
            }
        }
        .padding(.horizontal, 28).padding(.bottom, 20)
        .background(Theme.ground)
    }

    private func option(_ m: Mode, _ title: String, _ sub: String) -> some View {
        Button { choice = m } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 18, weight: .semibold)).tracking(-0.36)
                Text(sub).font(.sub).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.vertical, 18)
            .background(Theme.surface, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(choice == m ? Color(hex: 0x578bfa) : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
