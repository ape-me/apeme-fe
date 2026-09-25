import SwiftUI

/// The launch screen and the sign-in screen are one view, so the logo that builds itself in the
/// middle on cold launch is the same logo that then moves up to the corner of the welcome.
///
/// - `launch`: cold start. The logo builds, and it holds until auth has settled. Signed in, it
///   fades out into the app. Signed out, it docks and becomes the welcome.
/// - `signedOut`: reached by signing out. Plays the whole thing.
/// - `replay`: from You. Same screen, one Continue button instead of the sign-in buttons.
struct WelcomeView: View {
    enum Kind { case launch, signedOut, replay }
    let kind: Kind
    var onFinish: () -> Void = {}

    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Logo parts
    @State private var top: CGFloat = 0
    @State private var arrow = 0
    @State private var bottom: CGFloat = 0
    @State private var glow: CGFloat = 0
    @State private var glowGone = false
    @State private var docked = false
    // Welcome parts
    @State private var card = false
    @State private var lines = [false, false, false]
    @State private var sub = false
    @State private var buttons = [false, false]
    @State private var terms = false
    @State private var leaving = false

    @State private var busy = false
    @State private var error: String?
    @State private var emailSheet = false

    private static let centerW: CGFloat = 224
    private static let dockW: CGFloat = 124


    var body: some View {
        GeometryReader { g in
            let m = LogoMetrics(width: Self.centerW)
            let s = Self.dockW / Self.centerW
            let center = CGPoint(x: (g.size.width - Self.centerW) / 2, y: (g.size.height - m.height) / 2 - 10)
            let dock = CGPoint(x: 24, y: 16)
            ZStack(alignment: .topLeading) {
                Brand.black.ignoresSafeArea()

                Circle()
                    .fill(RadialGradient(colors: [Brand.lime.opacity(0.28), Brand.lime.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 221))
                    .frame(width: 520, height: 520)
                    .scaleEffect(glowGone ? 1.6 : 0.6 + 0.4 * glow)
                    .opacity(glowGone ? 0 : glow)
                    .position(x: g.size.width / 2, y: g.size.height / 2)
                    .allowsHitTesting(false)

                content(logoHeight: m.height * s)
                    .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)

                LogoMark(width: Self.centerW, top: top, arrow: arrow, bottom: bottom)
                    .scaleEffect(docked ? s : 1, anchor: .topLeading)
                    .offset(x: docked ? dock.x : center.x, y: docked ? dock.y : center.y)
                    .accessibilityLabel("Stonks247")
            }
            .opacity(leaving ? 0 : 1)
            .scaleEffect(leaving && !reduceMotion ? 1.04 : 1)
        }
        // No background out here: it would sit outside the fade and hold a black sheet over the
        // app until the overlay was removed. The ZStack's own black fades with everything else.
        .task { await run() }
        .onChange(of: app.signedIn) { _, now in
            // Signed in from this screen: step aside for the app underneath. Only once the
            // welcome is showing — restoring a saved session on launch flips this too, well
            // before the account has loaded, and fading then landed on an empty screen.
            if now, kind == .launch, docked { finish() }
        }
        .sheet(isPresented: $emailSheet) { LoginSheet(emailOnly: true) }
    }

    // MARK: - Welcome content

    private func content(logoHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: logoHeight)
            MarketCard()
                .padding(.top, 30)
                .opacity(card ? 1 : 0).offset(y: card ? 0 : 24)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 0) {
                headline("THE MARKET", 0, Brand.white)
                headline("CLOSES.", 1, Brand.white)
                headline("WE DON’T.", 2, Brand.lime)
            }
            Text("Buy real shares of the world’s biggest companies. Any time, from your phone.")
                .font(Brand.body(18)).foregroundStyle(Brand.muted).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .opacity(sub ? 1 : 0).offset(y: sub ? 0 : 20)
            actions.padding(.top, 30)
            footnote
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .opacity(terms ? 1 : 0)
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 6)
    }

    private func headline(_ text: String, _ i: Int, _ color: Color) -> some View {
        let size: CGFloat = 66
        return Text(text)
            .font(Brand.display(size)).tracking(-0.005 * size)
            .foregroundStyle(color)
            .frame(height: size * 0.86)
            .offset(y: lines[i] ? 0 : size * 0.86 * 1.05)
            .frame(height: size * 0.86, alignment: .top)
            .clipped()
            .accessibilityHidden(i > 0)
            .accessibilityLabel(i == 0 ? "The market closes. We don’t." : "")
    }

    @ViewBuilder private var actions: some View {
        if kind == .replay {
            brandButton(label: "Continue", icon: nil, light: true, shown: buttons[0]) {
                app.onboarded = true; app.root(.home)
            }
        } else {
            VStack(spacing: 12) {
                brandButton(label: "Continue with Apple", icon: "apple.logo", light: true, shown: buttons[0]) { apple() }
                brandButton(label: "Continue with email", icon: "envelope", light: false, shown: buttons[1]) {
                    prepareMode(); emailSheet = true
                }
            }
            .disabled(busy)
        }
    }

    @ViewBuilder private var footnote: some View {
        if let error {
            Text(error).font(Brand.body(14)).foregroundStyle(Theme.red).multilineTextAlignment(.center)
        } else if kind != .replay {
            let terms = Text("Terms").font(Brand.body(14, semibold: true)).foregroundStyle(Brand.white.opacity(0.75))
            let privacy = Text("Privacy Policy").font(Brand.body(14, semibold: true)).foregroundStyle(Brand.white.opacity(0.75))
            Text("By continuing you agree to the \(terms) and \(privacy).")
                .font(Brand.body(14)).foregroundStyle(Color(hex: 0x6E6E75))
                .multilineTextAlignment(.center)
        }
    }

    private func brandButton(label: String, icon: String?, light: Bool, shown: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy, light, icon != nil { ProgressView().tint(Brand.black) }
                else if let icon { Image(systemName: icon).font(.system(size: 19, weight: .semibold)) }
                Text(label).font(Brand.body(19, semibold: true))
            }
            .foregroundStyle(light ? Brand.black : Brand.white)
            .frame(maxWidth: .infinity).frame(height: 58)
            .background(light ? Brand.white : Brand.charcoal, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay {
                if !light { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line, lineWidth: 1) }
            }
        }
        .buttonStyle(PressScale())
        .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 28)
    }

    // MARK: - Sequence

    /// The logo is built in half a second, and nothing holds it there once it is.
    private func run() async {
        if reduceMotion { return await runReduced() }
        withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.36)) { top = 1 }
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.4)) { glow = 1 }
        try? await sleep(110)
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.16)) { arrow = 1 }
        try? await sleep(50)
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.34)) { bottom = 1 }
        try? await sleep(110)
        withAnimation(.timingCurve(0.34, 1.56, 0.64, 1, duration: 0.2)) { arrow = 2 }
        try? await sleep(230)                                  // ≈ 500ms: built

        if kind == .launch {
            let deadline = Date.now.addingTimeInterval(5)
            while !app.auth.ready, Date.now < deadline { try? await sleep(30) }
            if app.signedIn {
                // Hold until the account has loaded, so the fade lands on Home and not on a
                // blank loading screen.
                while app.auth.me == nil, !app.auth.meTried, Date.now < deadline { try? await sleep(30) }
                return finish()
            }
        }
        await reveal()
    }

    /// The glow blows out, the logo docks, and the page rises under it in well under a second.
    private func reveal() async {
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.4)) { glowGone = true }
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.45)) { docked = true }
        try? await sleep(80)
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.45)) { card = true }
        for i in 0..<3 {
            try? await sleep(50)
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.45)) { lines[i] = true }
        }
        try? await sleep(60)
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.4)) { sub = true }
        for i in 0..<2 {
            try? await sleep(50)
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.4)) { buttons[i] = true }
        }
        try? await sleep(100)
        withAnimation(.easeOut(duration: 0.3)) { terms = true }
    }

    private func runReduced() async {
        top = 1; arrow = 2; bottom = 1
        if kind == .launch {
            try? await sleep(600)
            while !app.auth.ready { try? await sleep(50) }
            if app.signedIn { return finish() }
        }
        withAnimation(.easeOut(duration: 0.3)) {
            docked = true; card = true; lines = [true, true, true]; sub = true; buttons = [true, true]; terms = true; glowGone = true
        }
    }

    private func finish() {
        guard !leaving else { return }
        withAnimation(.easeOut(duration: 0.25)) { glowGone = true; leaving = true }
        Task { try? await sleep(240); onFinish() }
    }

    private func sleep(_ ms: Int) async throws { try await Task.sleep(for: .milliseconds(ms)) }

    // MARK: - Sign in

    /// One mode exists while Ape is hidden; set it before sign-in so the app does not ask after.
    private func prepareMode() {
        if !Feature.ape, app.mode == nil { app.mode = .invest }
    }

    private func apple() {
        prepareMode()
        error = nil; busy = true
        Task {
            defer { busy = false }
            do {
                try await app.auth.loginWithApple()
                Haptic.success()
                app.onboarded = true
                await app.loadWallet()
            } catch {
                self.error = LoginForm.message(for: error, emailCode: false)
            }
        }
    }
}

/// The promise, proved: New York is shut and we are not. The clock is live.
private struct MarketCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private static let ny = TimeZone(identifier: "America/New_York")!

    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let open = Self.nyseOpen(ctx.date)
            VStack(alignment: .leading, spacing: 0) {
                row(dot: open ? Brand.white : Color(hex: 0x5A5A60), name: "New York Stock Exchange",
                    nameColor: open ? Brand.white : Brand.muted, status: open ? "OPEN" : "CLOSED",
                    statusColor: open ? Brand.white : Brand.muted, live: false)
                row(dot: Brand.lime, name: "Stonks247", nameColor: Brand.white,
                    status: "OPEN", statusColor: Brand.lime, live: true)
                    .padding(.top, 16)
                Rectangle().fill(Brand.line).frame(height: 1).padding(.top, 18)
                Text("IT’S \(Self.time(ctx.date)) IN NEW YORK")
                    .font(.system(size: 13, weight: .medium, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(Color(hex: 0x6E6E75))
                    .padding(.top, 16)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0x131315), in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Brand.line, lineWidth: 1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private func row(dot: Color, name: String, nameColor: Color, status: String, statusColor: Color, live: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                if live {
                    Circle().stroke(Brand.lime.opacity(0.5), lineWidth: 2)
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulse ? 2 : 1).opacity(pulse ? 0 : 1)
                    Circle().stroke(Brand.lime.opacity(0.35), lineWidth: 3).frame(width: 16, height: 16)
                }
                Circle().fill(dot).frame(width: 10, height: 10)
            }
            .frame(width: 16, height: 16)
            Text(name).font(Brand.body(19, semibold: true)).foregroundStyle(nameColor).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(status).font(.system(size: 15, weight: .medium, design: .monospaced)).tracking(1.6)
                .foregroundStyle(statusColor)
        }
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = ny; f.dateFormat = "h:mm a"
        return f
    }()
    static func time(_ d: Date) -> String { clock.string(from: d).uppercased() }

    /// Regular session, weekdays 9:30–16:00 New York. Holidays are not modelled.
    static func nyseOpen(_ d: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ny
        let c = cal.dateComponents([.weekday, .hour, .minute], from: d)
        guard let wd = c.weekday, (2...6).contains(wd), let h = c.hour, let m = c.minute else { return false }
        let mins = h * 60 + m
        return mins >= 570 && mins < 960
    }
}
