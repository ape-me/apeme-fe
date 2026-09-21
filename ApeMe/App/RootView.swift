import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            if !app.auth.ready {
                Color.clear
            } else if !app.signedIn {
                SignedOutFlow()               // slides → Get started → Sign in, every launch until login succeeds
            } else if app.auth.me == nil {
                AccountLoadingView(failed: app.auth.meTried)
            } else if app.needsInvite {
                InviteView()                  // wall: nothing behind it until /v1/me says active
            } else if !app.onboarded || app.mode == nil {
                OnboardingView()              // replay from You
            } else {
                MainShell()
            }
        }
        .animation(.easeOut(duration: 0.25), value: app.signedIn)
        .background(Theme.ground)
        .sheet(item: $app.sheet) { sheet in
            switch sheet {
            case .buyStock(let s): BuySheet(kind: .stock, stock: s, token: nil, stockRef: nil)
            case .apeToken(let t, let ref): BuySheet(kind: .token, stock: nil, token: t, stockRef: ref)
            case .deposit: DepositSheet()
            case .login: LoginSheet()
            }
        }
        .overlay(alignment: .bottom) {
            if let t = app.toast {
                ToastView(text: t)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: app.toast)
    }
}

/// Slides first, then the login screen. Nothing is persisted until the user is actually signed in.
private struct SignedOutFlow: View {
    @State private var showLogin = false
    var body: some View {
        if showLogin {
            LoginView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            OnboardingView(onGetStarted: { withAnimation(.easeOut(duration: 0.25)) { showLogin = true } })
        }
    }
}

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
                        case .floor(let mint): FloorView(mint: mint)
                        case .token(let mint): TokenView(mint: mint)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.ink)
    }

    @ViewBuilder private var tabRoot: some View {
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
        .background(Theme.ground)
    }
}
