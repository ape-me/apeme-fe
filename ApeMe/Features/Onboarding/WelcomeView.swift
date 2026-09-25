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
    @State private var pouring = false
    @State private var lines = [false, false]
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

                // Behind everything: the coin pile, then a wash that keeps the words readable.
                // The logo is a solid object in the coins' world, so they bounce off it and it
                // keeps the clear space the kit asks for. Screen coordinates, safe area included.
                CoinField(pouring: pouring,
                          avoid: CGRect(x: dock.x - 14, y: dock.y + g.safeAreaInsets.top - 12,
                                        width: Self.dockW + 28, height: m.height * s + 24))
                    .ignoresSafeArea()
                LinearGradient(stops: [.init(color: Brand.black.opacity(0.35), location: 0),
                                       .init(color: Brand.black.opacity(0), location: 0.22),
                                       .init(color: Brand.black.opacity(0), location: 0.45),
                                       .init(color: Brand.black.opacity(0.7), location: 0.66),
                                       .init(color: Brand.black.opacity(0.85), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
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
            guard now, kind == .launch, docked else { return }
            Task {
                // Signed in from here, or a slow session restore landing late: either way, let
                // the account load before fading so there is something underneath.
                let deadline = Date.now.addingTimeInterval(4)
                while (!app.auth.ready || (app.auth.me == nil && !app.auth.meTried)), Date.now < deadline { try? await sleep(30) }
                finish()
            }
        }
        .sheet(isPresented: $emailSheet) { LoginSheet(emailOnly: true) }
    }

    // MARK: - Welcome content

    private func content(logoHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: logoHeight)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 0) {
                headline("WALL STREET,", 0, Brand.white)
                headline("OPEN 24/7.", 1, Brand.lime)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Wall Street, open 24/7.")
            actions.padding(.top, 28)
            footnote
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .opacity(terms ? 1 : 0)
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 6)
    }

    /// One line of the headline, rising out of its own mask.
    private func headline(_ text: String, _ i: Int, _ color: Color) -> some View {
        // 68pt: "WALL STREET," still fits a 375pt-wide phone inside the 24pt margins.
        let size: CGFloat = 68
        return Text(text)
            .font(Brand.display(size)).tracking(-0.005 * size)
            .foregroundStyle(color)
            .fixedSize()
            .frame(height: size * 0.86)
            .offset(y: lines[i] ? 0 : size * 0.86 * 1.05)
            .frame(height: size * 0.86, alignment: .top)
            .clipped()
    }

    @ViewBuilder private var actions: some View {
        if kind == .replay {
            brandButton(label: "Continue", icon: nil, light: true, shown: buttons[0]) {
                app.onboarded = true; app.replayingIntro = false; app.root(.home)
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
            // Don't sit on the logo waiting for a signed-out check. If a saved session turns up
            // after the welcome is showing, the signed-in handler fades it into the app anyway.
            let deadline = Date.now.addingTimeInterval(0.8)
            while !app.auth.ready, Date.now < deadline { try? await sleep(30) }
            if app.signedIn {
                // Hold until the account has loaded, so the fade lands on Home and not on a
                // blank loading screen.
                let meDeadline = Date.now.addingTimeInterval(4)
                while (!app.auth.ready || (app.auth.me == nil && !app.auth.meTried)), Date.now < meDeadline { try? await sleep(30) }
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
        pouring = true
        for i in lines.indices {
            try? await sleep(60)
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)) { lines[i] = true }
        }
        try? await sleep(40)
        for i in buttons.indices {
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
            docked = true; pouring = true; lines = [true, true]; buttons = [true, true]; terms = true; glowGone = true
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
