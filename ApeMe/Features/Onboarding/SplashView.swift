import SwiftUI

/// Cold-launch only. The system launch screen is the same colour, so the hand-off is invisible;
/// the mark then blooms in, holds until auth has settled, and steps forward as it fades so the
/// app underneath reads as arriving rather than being revealed.
struct SplashView: View {
    let onFinish: () -> Void
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Stage { case hidden, shown, leaving }
    @State private var stage = Stage.hidden
    @State private var wordmark = false

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x578bfa).opacity(0.32), .clear],
                                     center: .center, startRadius: 0, endRadius: 230))
                .frame(width: 460, height: 460)
                .scaleEffect(stage == .hidden ? 0.4 : 1)
                .opacity(stage == .shown ? 1 : 0)
            VStack(spacing: 20) {
                BrandMark(size: 96)
                    .scaleEffect(stage == .hidden ? 0.7 : stage == .shown ? 1 : 1.15)
                    .blur(radius: stage == .hidden ? 12 : 0)
                Text("ApeMe")
                    .font(.system(size: 30, weight: .bold)).tracking(-1)
                    .opacity(wordmark ? 1 : 0)
                    .offset(y: wordmark ? 0 : 12)
            }
            .opacity(stage == .shown ? 1 : 0)
        }
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            stage = .shown; wordmark = true
        } else {
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(.spring(duration: 0.75, bounce: 0.22)) { stage = .shown }
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(.timingCurve(0.19, 1, 0.22, 1, duration: 0.6)) { wordmark = true }
        }
        // Long enough to register, and never shorter than the time auth needs anyway.
        try? await Task.sleep(for: .milliseconds(900))
        let deadline = Date.now.addingTimeInterval(5)
        while !app.auth.ready, Date.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.38)) { stage = .leaving }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 340))
        onFinish()
    }
}
