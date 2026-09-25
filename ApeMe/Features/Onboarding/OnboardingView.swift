import SwiftUI

/// Three pages, each built around one moving picture of the product: the stocks you can own
/// orbiting the mark, a live price pulling away from its fair value, and an order filling at
/// the price someone set. The picture plays when its page lands and rests when it leaves.
struct OnboardingView: View {
    /// Signed out: Get started hands over to the login screen. Signed in (replay from You): straight back to Home.
    var onGetStarted: (() -> Void)? = nil
    @Environment(AppState.self) private var app
    @State private var index = 0
    @State private var choice: Mode? = nil

    private static var pages: Int { Feature.ape ? 4 : 3 }
    private static var lastPage: Int { pages - 1 }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            Backdrop(index: index)
            VStack(spacing: 0) {
                topBar
                TabView(selection: $index) {
                    Page(title: "Own it before\nthe IPO.",
                         text: "OpenAI, Anthropic, Neuralink — tokenized on Solana. Start from $1, trade any hour.",
                         active: index == 0) { OrbitHero(active: index == 0) }
                        .tag(0)
                    Page(title: "Know what it's\nreally worth.",
                         text: "Every stock carries a fair value, and shows how far the price has run from it.",
                         active: index == 1) { FairValueHero(active: index == 1) }
                        .tag(1)
                    if Feature.ape {
                        Page(title: "Every stock\nhas a floor.",
                             text: "Community tokens launch against each stock. Buy the stock, or ape the memes on its floor.",
                             active: index == 2) { FloorHero() }
                            .tag(2)
                        question.tag(3)
                    } else {
                        Page(title: "Name your price.\nWalk away.",
                             text: "Leave an order at the price you want and it waits there for you. No seed phrase, no wallet to manage.",
                             active: index == 2) { LimitHero(active: index == 2) }
                            .tag(2)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                footer
            }
        }
        .environment(\.skin, Skin(mode: .invest))
        .sensoryFeedback(.selection, trigger: index)
    }

    private var topBar: some View {
        HStack {
            BrandLockup(size: 26)
            Spacer()
            if index < Self.lastPage {
                Button("Skip") {
                    if Feature.ape { withAnimation(.snappy) { index = Self.lastPage } } else { finish() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
        .padding(.horizontal, 24).padding(.top, 10).frame(height: 44)
    }

    private var footer: some View {
        VStack(spacing: 22) {
            HStack(spacing: 6) {
                ForEach(0..<Self.pages, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Theme.ink : Theme.line)
                        .frame(width: i == index ? 24 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0), value: index)
            .frame(maxWidth: .infinity, alignment: .leading)
            BigButton(label: index < Self.lastPage ? "Continue" : "Get started",
                      style: Feature.ape && index == Self.lastPage && choice == nil ? .off : .white) {
                if index < Self.lastPage { withAnimation(.snappy) { index += 1 } } else { finish() }
            }
        }
        .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 20)
    }

    private func finish() {
        // Without the question there is one mode, and this is it.
        guard let picked = Feature.ape ? choice : .invest else { return }
        app.mode = picked
        if let onGetStarted { onGetStarted() } else { app.onboarded = true; app.root(.home) }
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

// MARK: - Page chrome

/// Hero on top, words underneath. The words rise in a beat after the page settles, so a swipe
/// reads as the picture arriving first and the sentence explaining it.
private struct Page<Hero: View>: View {
    let title: String
    let text: String
    let active: Bool
    @ViewBuilder let hero: Hero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero.frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 36, weight: .bold)).tracking(-1.4).lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 18)
                    .animation(ease.delay(0.05), value: shown)
                Text(text)
                    .font(.system(size: 16)).foregroundStyle(Theme.muted).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 14)
                    .animation(ease.delay(0.12), value: shown)
            }
            .padding(.horizontal, 28).padding(.bottom, 12)
        }
        .task { try? await Task.sleep(for: .milliseconds(180)); appeared = true }
    }

    private var shown: Bool { (active && appeared) || reduceMotion }
    private var ease: Animation { .timingCurve(0.19, 1, 0.22, 1, duration: 0.6) }
}

/// A slow wash of colour behind everything that drifts to a new place and hue per page.
private struct Backdrop: View {
    let index: Int
    private var spot: (Color, CGFloat, CGFloat) {
        switch index {
        case 0: (Color(hex: 0x578bfa), 0, -200)
        case 1: (Theme.amber, 120, -170)
        default: (Theme.buy, -110, -150)
        }
    }
    var body: some View {
        Circle()
            .fill(spot.0)
            .frame(width: 380, height: 380)
            .blur(radius: 140)
            .opacity(0.3)
            .offset(x: spot.1, y: spot.2)
            .animation(.easeInOut(duration: 0.9), value: index)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

// MARK: - Page 1: the orbit

private struct Chip: Identifiable {
    let id: String
    let initial: String
    let tint: Color
    let ink: Color
    let ring: Int
    let phase: Double
}

private struct OrbitHero: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false
    @State private var start = Date.now

    private static let chips: [Chip] = [
        Chip(id: "OPENAI", initial: "O", tint: .white, ink: .black, ring: 0, phase: 0.2),
        Chip(id: "ANTHROPIC", initial: "A", tint: Color(hex: 0xd97757), ink: .white, ring: 0, phase: 1.8),
        Chip(id: "NEURALINK", initial: "N", tint: Color(hex: 0xe8e8ec), ink: .black, ring: 0, phase: 3.4),
        Chip(id: "POLYMARKET", initial: "P", tint: Color(hex: 0x2d6bff), ink: .white, ring: 0, phase: 4.9),
        Chip(id: "KALSHI", initial: "K", tint: Color(hex: 0x00d3a1), ink: .black, ring: 1, phase: 0.9),
        Chip(id: "ANDURIL", initial: "A", tint: Color(hex: 0x2a2e35), ink: .white, ring: 1, phase: 3.0),
        Chip(id: "FIGUREAI", initial: "F", tint: .black, ink: .white, ring: 1, phase: 5.1),
    ]

    var body: some View {
        GeometryReader { g in
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let radii = [CGSize(width: g.size.width * 0.33, height: g.size.height * 0.33),
                         CGSize(width: g.size.width * 0.19, height: g.size.height * 0.19)]
            TimelineView(.animation(paused: !active || reduceMotion)) { ctx in
                let t = ctx.date.timeIntervalSince(start)
                ZStack {
                    ForEach(0..<2, id: \.self) { r in
                        Ellipse()
                            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: r == 0 ? [] : [3, 5]))
                            .frame(width: radii[r].width * 2, height: radii[r].height * 2)
                            .rotationEffect(.degrees(-12))
                            .position(c)
                            .opacity(entered ? 1 : 0)
                            .scaleEffect(entered ? 1 : 0.6)
                    }
                    BrandMark(size: 68)
                        .position(c)
                        .scaleEffect(entered ? 1 : 0.5)
                        .opacity(entered ? 1 : 0)
                    ForEach(Array(Self.chips.enumerated()), id: \.element.id) { i, chip in
                        let speed = chip.ring == 0 ? 0.18 : -0.26
                        let a = chip.phase + t * speed
                        let p = orbit(a, radii[chip.ring], tilt: -12)
                        let depth = (sin(a) + 1) / 2
                        ChipView(chip: chip)
                            .scaleEffect(0.74 + 0.3 * depth)
                            .opacity(entered ? 0.4 + 0.6 * depth : 0)
                            .position(entered ? CGPoint(x: c.x + p.x, y: c.y + p.y) : c)
                            .zIndex(chip.ring == 0 ? depth * 2 - 0.5 : depth)
                            .animation(.spring(duration: 0.8, bounce: 0.18).delay(Double(i) * 0.05), value: entered)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.7, bounce: 0.15), value: entered)
        .onChange(of: active, initial: true) { _, on in
            if on {
                entered = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(40))
                    entered = true
                }
            }
        }
    }

    private func orbit(_ a: Double, _ r: CGSize, tilt deg: Double) -> CGPoint {
        let x = cos(a) * r.width, y = sin(a) * r.height
        let th = deg * .pi / 180
        return CGPoint(x: x * cos(th) - y * sin(th), y: x * sin(th) + y * cos(th))
    }
}

private struct ChipView: View {
    let chip: Chip
    var body: some View {
        HStack(spacing: 8) {
            Text(chip.initial)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(chip.ink)
                .frame(width: 24, height: 24)
                .background(chip.tint, in: .circle)
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            Text(chip.id).font(.system(size: 13, weight: .semibold)).tracking(-0.2)
        }
        .fixedSize()
        .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
        .background(Theme.surface.opacity(0.92), in: .capsule)
        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
    }
}

// MARK: - Page 2: price vs fair value

private struct FairValueHero: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var price: Double = 880
    @State private var tag = false
    @State private var pulse = false

    private let blue = Color(hex: 0x578bfa)

    var body: some View {
        ZStack {
            // A second card behind for depth, the way a stack of stocks would sit.
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.surface.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.05)))
                .frame(height: 290)
                .padding(.horizontal, 44)
                .rotationEffect(.degrees(tag ? 5 : 0))
                .offset(y: tag ? -26 : 0)
            card
                .padding(.horizontal, 28)
        }
        .onChange(of: active, initial: true) { _, on in on ? play() : reset() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("A").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(Color(hex: 0xd97757), in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("ANTHROPIC").font(.system(size: 15, weight: .semibold))
                    Text("Pre-IPO").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(Fmt.usd(price))
                    .font(.system(size: 20, weight: .bold)).monospacedDigit()
                    .contentTransition(.numericText(value: price))
            }
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                let fair = h * 0.8
                let end = CGPoint(x: w, y: h * 0.14)
                ZStack(alignment: .topLeading) {
                    Path { p in p.move(to: .init(x: 0, y: fair)); p.addLine(to: .init(x: w, y: fair)) }
                        .stroke(Theme.amber.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                        .opacity(drawn > 0.3 ? 1 : 0)
                    line(w, h).trim(from: 0, to: drawn)
                        .stroke(blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    line(w, h).trim(from: 0, to: drawn)
                        .stroke(blue.opacity(0.35), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .blur(radius: 8)
                    Circle().fill(blue.opacity(0.25)).frame(width: 30, height: 30)
                        .scaleEffect(pulse ? 1.25 : 0.6).opacity(pulse ? 0 : 1)
                        .position(end).opacity(tag ? 1 : 0)
                    Circle().fill(blue).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.ground, lineWidth: 2))
                        .position(end).opacity(tag ? 1 : 0)
                    Text("Fair value").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.amber)
                        .position(x: 34, y: fair + 14)
                        .opacity(drawn > 0.3 ? 1 : 0)
                    Path { p in p.move(to: .init(x: w, y: end.y + 10)); p.addLine(to: .init(x: w, y: fair)) }
                        .trim(from: 0, to: tag ? 1 : 0)
                        .stroke(Theme.amber.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    Text("+15% above").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.amber)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.amberT, in: .capsule)
                        .overlay(Capsule().stroke(Theme.amber.opacity(0.35), lineWidth: 1))
                        .scaleEffect(tag ? 1 : 0.4, anchor: .trailing)
                        .opacity(tag ? 1 : 0)
                        .position(x: w - 58, y: (end.y + fair) / 2 + 8)
                }
            }
            .frame(height: 170)
        }
        .padding(18)
        .background(Theme.surface, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
    }

    private func line(_ w: CGFloat, _ h: CGFloat) -> Path {
        Path { p in
            p.move(to: .init(x: 0, y: h * 0.84))
            p.addCurve(to: .init(x: w * 0.3, y: h * 0.66), control1: .init(x: w * 0.1, y: h * 0.9), control2: .init(x: w * 0.2, y: h * 0.6))
            p.addCurve(to: .init(x: w * 0.62, y: h * 0.42), control1: .init(x: w * 0.42, y: h * 0.74), control2: .init(x: w * 0.5, y: h * 0.4))
            p.addCurve(to: .init(x: w, y: h * 0.14), control1: .init(x: w * 0.76, y: h * 0.46), control2: .init(x: w * 0.86, y: h * 0.12))
        }
    }

    private func play() {
        guard !reduceMotion else { drawn = 1; price = 1027.90; tag = true; return }
        reset()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.timingCurve(0.33, 1, 0.68, 1, duration: 1.3)) { drawn = 1; price = 1027.90 }
            try? await Task.sleep(for: .milliseconds(1000))
            withAnimation(.spring(duration: 0.55, bounce: 0.3)) { tag = true }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private func reset() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { drawn = 0; price = 880; tag = false; pulse = false }
    }
}

// MARK: - Page 3: an order that fills itself

private struct LimitHero: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var lastCycle = -1

    private static let period = 5.2
    private static let travel = 2.6
    private let blue = Color(hex: 0x578bfa)

    var body: some View {
        TimelineView(.animation(paused: !active || reduceMotion)) { ctx in
            let e = reduceMotion ? Self.travel + 1 : ctx.date.timeIntervalSince(start)
            let p = e.truncatingRemainder(dividingBy: Self.period)
            let prog = easeInOut(min(p / Self.travel, 1))
            let filled = p >= Self.travel
            let pop = filled ? backOut(min((p - Self.travel) / 0.45, 1)) : 0
            let fade = p > Self.period - 0.4 ? (Self.period - p) / 0.4 : 1
            card(prog: prog, filled: filled, pop: pop, fade: reduceMotion ? 1 : fade)
                .onChange(of: filled) { _, f in if f, active { Haptic.success() } }
        }
        .padding(.horizontal, 28)
        .onChange(of: active) { _, on in if on { start = .now } }
    }

    private func card(prog: Double, filled: Bool, pop: Double, fade: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Buy NVDAX at").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                    Text("$172.00").font(.system(size: 26, weight: .bold)).tracking(-0.8).monospacedDigit()
                }
                Spacer()
                status(filled: filled, pop: pop).opacity(fade)
            }
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                let pts = samples(w, h)
                let n = max(1, Int(Double(pts.count - 1) * prog))
                let head = pts[n]
                let target = h * 0.78
                let color = filled ? Theme.buy : blue
                ZStack(alignment: .topLeading) {
                    Path { p in p.move(to: .init(x: 0, y: target)); p.addLine(to: .init(x: w, y: target)) }
                        .stroke(Theme.amber.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                    Text("Your price").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.amber)
                        .position(x: 34, y: target + 14)
                    Group {
                        Path { p in p.addLines(Array(pts[0...n])) }
                            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        Circle().fill(color.opacity(0.3)).frame(width: 34, height: 34)
                            .scaleEffect(filled ? 1 + pop * 0.4 : 0.6).opacity(filled ? 1 - pop * 0.8 : 0.8)
                            .position(head)
                        Circle().fill(color).frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Theme.ground, lineWidth: 2))
                            .position(head)
                    }
                    .opacity(fade)
                }
            }
            .frame(height: 170)
        }
        .padding(18)
        .background(Theme.surface, in: .rect(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
    }

    @ViewBuilder private func status(filled: Bool, pop: Double) -> some View {
        ZStack {
            HStack(spacing: 6) {
                Circle().fill(Theme.amber).frame(width: 6, height: 6)
                Text("Waiting").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.amber)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.amberT, in: .capsule)
            .opacity(filled ? 0 : 1)
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
                Text("Filled").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.green)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.greenT, in: .capsule)
            .scaleEffect(filled ? 0.6 + 0.4 * pop : 0.6)
            .opacity(filled ? 1 : 0)
        }
    }

    /// A price that wanders down to the line rather than walking straight to it.
    private func samples(_ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        (0...80).map { i in
            let x = Double(i) / 80
            let y = 0.2 + 0.58 * x + 0.07 * sin(x * 12) * (1 - x)
            return CGPoint(x: CGFloat(x) * w, y: CGFloat(y) * h)
        }
    }

    private func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
    private func backOut(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

// MARK: - Ape-only page, kept behind the flag

private struct FloorHero: View {
    var body: some View {
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
        .padding(.horizontal, 28)
    }
}
