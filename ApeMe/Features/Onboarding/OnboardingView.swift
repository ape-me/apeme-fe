import SwiftUI

/// Three slides and one question. The answer sets the mode.
struct OnboardingView: View {
    /// Signed out: Get started hands over to the login screen. Signed in (replay from You): straight back to Home.
    var onGetStarted: (() -> Void)? = nil
    @Environment(AppState.self) private var app
    @State private var index = 0
    @State private var choice: Mode? = nil

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $index) {
                slide1.tag(0)
                slide2.tag(1)
                slide3.tag(2)
                question.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            VStack(spacing: 14) {
                HStack(spacing: 5) {
                    ForEach(0..<4) { i in
                        Circle().fill(i == index ? Theme.muted : Theme.line).frame(width: 5, height: 5)
                    }
                }
                BigButton(label: index < 3 ? "Continue" : "Get started",
                          style: index == 3 && choice == nil ? .off : .white) {
                    if index < 3 { withAnimation { index += 1 } }
                    else if let choice {
                        app.mode = choice
                        if let onGetStarted { onGetStarted() } else { app.onboarded = true; app.root(.home) }
                    }
                }
            }
            .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 20)
        }
        .background(Theme.ground)
        .environment(\.skin, Skin(mode: .invest))
    }

    private func slide(_ title: String, _ body: String, @ViewBuilder art: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            art().frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(title).font(.system(size: 32, weight: .semibold)).tracking(-1.3).lineSpacing(2)
            Text(body).font(.body15).foregroundStyle(Theme.muted).lineSpacing(3)
        }
        .padding(.horizontal, 28).padding(.bottom, 24)
    }

    private var slide1: some View {
        slide("Own the stocks that aren't public yet.",
              "OpenAI, Anthropic, Neuralink — tokenized on Solana. Trade them 24/7 with as little as $1.") {
            GeometryReader { g in
                let tk: [(String, CGFloat, CGFloat, Double, Color, Color)] = [
                    ("OPENAI", 0.06, 0.18, -14, Color(hex: 0xc8f58a), Theme.ground),
                    ("ANTHROPIC", 0.38, 0.10, 9, .white, Theme.ground),
                    ("NEURALINK", 0.58, 0.34, -6, Color(hex: 0xc8f58a), Theme.ground),
                    ("NVDAx", 0.10, 0.48, 17, .white, Theme.ground),
                    ("AAPLx", 0.44, 0.58, -12, Color(hex: 0x0f1319), .white),
                    ("POLYMARKET", 0.24, 0.76, 7, Color(hex: 0xc8f58a), Theme.ground),
                ]
                ForEach(tk.indices, id: \.self) { i in
                    let t = tk[i]
                    Text(t.0)
                        .font(.system(size: 17, weight: .bold)).tracking(-0.3)
                        .foregroundStyle(t.5)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(t.4, in: .capsule)
                        .overlay(Capsule().stroke(Color(hex: 0x2a2e35), lineWidth: t.4 == Color(hex: 0x0f1319) ? 1 : 0))
                        .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
                        .rotationEffect(.degrees(t.3))
                        .offset(x: g.size.width * t.1, y: g.size.height * t.2)
                }
            }
        }
    }

    private var slide2: some View {
        slide("See what people pay vs. what it's worth.",
              "Every pre-IPO stock has a fair value. The gap is the premium — and we show it on every card.") {
            PremiumArt()
        }
    }

    private var slide3: some View {
        slide("Every stock has a floor.",
              "Community tokens launch against each stock. Buy the stock, or ape the memes on its floor.") {
            GeometryReader { g in
                let orbs: [(CGFloat, CGFloat, CGFloat, Color)] = [
                    (0.14, 0.26, 52, Color(hex: 0xd97757)), (0.66, 0.14, 44, Color(hex: 0x6db3ff)),
                    (0.72, 0.58, 60, Color(hex: 0x5fe39a)), (0.22, 0.70, 40, Theme.amber),
                ]
                ForEach(orbs.indices, id: \.self) { i in
                    Circle().fill(orbs[i].3).frame(width: orbs[i].2, height: orbs[i].2)
                        .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
                        .offset(x: g.size.width * orbs[i].0, y: g.size.height * orbs[i].1)
                }
                Circle().fill(.white).frame(width: 72, height: 72)
                    .overlay(Text("🦍").font(.system(size: 30)))
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
                    .offset(x: g.size.width * 0.48, y: g.size.height * 0.44)
            }
        }
    }

    private var question: some View {
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
        }
        .padding(.horizontal, 28)
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

/// Slide 2 art: the two-line mini chart with the +15% tag.
private struct PremiumArt: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let sx = w / 320, sy = h / 200
            let line = Path { p in
                p.move(to: CGPoint(x: 0, y: 130 * sy))
                p.addCurve(to: CGPoint(x: 90 * sx, y: 112 * sy), control1: CGPoint(x: 40 * sx, y: 128 * sy), control2: CGPoint(x: 60 * sx, y: 110 * sy))
                p.addCurve(to: CGPoint(x: 170 * sx, y: 92 * sy), control1: CGPoint(x: 120 * sx, y: 114 * sy), control2: CGPoint(x: 140 * sx, y: 96 * sy))
                p.addCurve(to: CGPoint(x: 260 * sx, y: 70 * sy), control1: CGPoint(x: 200 * sx, y: 88 * sy), control2: CGPoint(x: 230 * sx, y: 78 * sy))
                p.addCurve(to: CGPoint(x: 320 * sx, y: 58 * sy), control1: CGPoint(x: 290 * sx, y: 62 * sy), control2: CGPoint(x: 300 * sx, y: 66 * sy))
            }
            ZStack(alignment: .topLeading) {
                line.stroke(Color(hex: 0x578bfa), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                Path { p in p.move(to: CGPoint(x: 0, y: 150 * sy)); p.addLine(to: CGPoint(x: w, y: 138 * sy)) }
                    .stroke(Theme.amber, style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
                Circle().fill(Color(hex: 0x578bfa)).frame(width: 10, height: 10).position(x: w, y: 58 * sy)
                Text("+15%").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.amber)
                    .padding(.horizontal, 14).padding(.vertical, 6).background(Theme.amberT, in: .capsule)
                    .position(x: 272 * sx, y: 101 * sy)
                Text("What people pay").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex: 0x578bfa))
                    .offset(x: 8, y: 116 * sy)
                Text("Fair value").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.amber)
                    .offset(x: 8, y: 158 * sy)
            }
        }
    }
}
