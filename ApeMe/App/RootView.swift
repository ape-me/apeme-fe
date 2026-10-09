import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app
    /// Once per cold launch. RootView lives as long as the process, so this never replays.
    @State private var splashing = true

    var body: some View {
        @Bindable var app = app
        ZStack {
        Group {
            if !app.auth.ready || (splashing && !app.signedIn) {
                Color.clear                   // the launch overlay is the welcome while it is up
            } else if !app.signedIn {
                WelcomeView(kind: .signedOut) // reached by signing out
            } else if app.auth.me == nil {
                AccountLoadingView(failed: app.auth.meTried)
            } else if app.needsInvite {
                InviteView()                  // wall: nothing behind it until /v1/me says active
            } else if app.replayingIntro {
                WelcomeView(kind: .replay)    // replayed from You
            } else {
                MainShell().task(id: app.auth.me?.userId) { await app.syncWatchlist() }
            }
        }
        .animation(.easeOut(duration: 0.25), value: app.signedIn)
            #if DEBUG
            // `-previewWelcome` shows the signed-out welcome without signing anyone out.
            if ProcessInfo.processInfo.arguments.contains("-previewWelcome") {
                WelcomeView(kind: .signedOut).zIndex(2)
            }
            #endif
            if splashing {
                // Cold launch: the logo builds here, then either fades into the app or docks
                // and becomes the welcome, staying up until sign-in succeeds.
                WelcomeView(kind: .launch) { splashing = false }
                    .transition(.identity)
                    .zIndex(1)
            }
        }
        .background(Theme.ground)
        .task(id: app.signedIn) { if app.signedIn { app.startOrderFeed() } }
        .sheet(item: $app.sheet) { sheet in
            Group {
            switch sheet {
            case .buyStock(let s): TradeSheetView(side: .buy, asset: .stock(s))
            case .sell(let h): TradeSheetView(side: .sell, asset: .holding(h))
            case .deposit: DepositSheet()
            case .withdraw: WithdrawSheet()
            case .basket(let b, let usd):
                BasketOrderSheet(basketId: b.id, name: b.name, tagline: b.tagline,
                                 logos: (b.logos ?? []).prefix(5).compactMap(URL.init(string:)), sell: false, amountUsd: usd)
            case .closeBasket(let p):
                BasketOrderSheet(basketId: p.basketId, name: p.name, tagline: "\(p.stocks.count) stocks",
                                 logos: p.stocks.prefix(5).compactMap(\.logoURL), sell: true, amountUsd: 0)
            case .tx(let a): TxSheet(activity: a)
            case .resume(let r): TradeSheetView(resume: r)
            case .resumeBasket(let r): BasketOrderSheet(resume: r)
            case .position(let h): PositionSheet(holding: h)
            case .login: LoginSheet()
            }
            }
            .toastOverlay()
        }
        .toastOverlay()
    }
}

/// Toast at the top of whatever is frontmost — the root or a presented sheet.
private struct ToastOverlay: ViewModifier {
    @Environment(AppState.self) private var app
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let t = app.toast {
                    ToastView(text: t, error: app.toastIsError, pending: app.toastPending, image: app.toastImage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.25), value: app.toast)
    }
}
extension View { func toastOverlay() -> some View { modifier(ToastOverlay()) } }

/// Four root tabs in one navigation stack. The tab bar shows only at the root.
struct MainShell: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $app.path) {
            tabRoot
                .navigationDestination(for: Route.self) { route in
                    Group {
                        switch route {
                        case .stock(let mint): StockView(mint: mint)
                        case .basket(let id): BasketView(id: id)
                        case .baskets: BasketsListView()
                        case .basketPosition(let id): BasketPositionView(basketId: id)
                        case .settings: SettingsView()
                        case .referrals: ReferralsView()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.ink)
        // The wallet used to be fetched only when the Wallet tab opened, so Home's news, the
        // position card on a stock page and the sell flow all behaved as though nothing was
        // held until you had visited it once. Signed in is enough of a reason to load it.
        .task(id: app.walletAddress) {
            guard app.walletAddress != nil else { return }
            await app.loadWallet(fresh: true)
        }
    }

    @ViewBuilder private var tabRoot: some View {
        // The cover is a sibling in a ZStack, not an overlay on the content. An overlay is bounded
        // by the view it sits on, and that view starts below the clock — which is why two earlier
        // versions of this painted the bar underneath the status bar instead of over it.
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Group {
                    switch app.tab {
                    case .home: HomeView()
                    case .markets: MarketsView()
                    case .portfolio: PortfolioView()
                    case .you: YouView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                TabBar()
            }
            StatusBarCover()
        }
        .background(Theme.ground)
    }
}

/// Fills the status-bar inset with the page colour, so scrolling content is cut at that line
/// instead of reading through the clock.
///
/// The height has to be measured. A zero-height view that merely ignores the safe area does not
/// grow to fill it — it draws nothing, which is exactly what the first version of this did — and
/// a GeometryReader placed here reports a zero inset, because the overlay sits inside the safe
/// area already. The window knows, so ask the window. Portrait-only, so it cannot go stale.
private struct StatusBarCover: View {
    private var topInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }

    var body: some View {
        Theme.ground
            .frame(maxWidth: .infinity)
            .frame(height: topInset)
            // Pulled up by its own height so it lands on the status bar rather than on the first
            // line of content. An offset is purely visual and nothing here clips, so this does not
            // depend on ignoresSafeArea behaving a particular way.
            .offset(y: -topInset)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}
