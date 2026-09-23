import SwiftUI
import PrivySDK
import Observation

/// Mode, wallet, watchlists, navigation. Persisted bits go through UserDefaults directly so
/// observation still fires (`@AppStorage` does not work inside `@Observable`).
@Observable @MainActor
final class AppState {
    private let defaults = UserDefaults.standard

    var mode: Mode? { didSet { defaults.set(mode?.rawValue, forKey: "apeme.mode") } }
    /// Seen the slides and tapped Get started. Separate from `mode` so replaying onboarding never logs you out.
    var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "apeme.onboarded") } }
    var demoWallet: Bool { didSet { defaults.set(demoWallet, forKey: "apeme.demo"); if !demoWallet { wallet = nil } } }
    var watch: [String] { didSet { defaults.set(watch, forKey: "apeme.watch") } }
    var tokenWatch: [String] { didSet { defaults.set(tokenWatch, forKey: "apeme.tokenWatch") } }

    var tab: Tab = .home
    var path: [Route] = []
    var sheet: TradeSheet?
    var toast: String?
    var toastIsError = false
    /// Spinner toast that stays until replaced (a trade in flight).
    var toastPending = false
    /// Optional asset mark shown at the left of the toast (trades).
    var toastImage: ToastImage?
    var wallet: Wallet?
    var stocksByMint: [String: Stock] = [:]
    var online = true

    private var toastTask: Task<Void, Never>?

    init() {
        mode = defaults.string(forKey: "apeme.mode").flatMap(Mode.init(rawValue:))
        onboarded = defaults.bool(forKey: "apeme.onboarded")
        demoWallet = defaults.bool(forKey: "apeme.demo")
        watch = defaults.stringArray(forKey: "apeme.watch") ?? []
        tokenWatch = defaults.stringArray(forKey: "apeme.tokenWatch") ?? []
    }

    var isApe: Bool { mode == .ape }

    /// Privy wallet when signed in, the demo wallet when that's switched on, otherwise nothing.
    let auth = Auth.shared
    var signedIn: Bool { auth.user != nil }
    var walletAddress: String? { auth.address }
    var hasWallet: Bool { walletAddress != nil }
    /// Signed in but not yet let through the invite gate. Browsing works; trading opens the invite sheet.
    var needsInvite: Bool { signedIn && auth.needsInvite }

    func trade(_ s: TradeSheet) { sheet = s }

    /// Sell whatever the active account holds of this mint; refreshes the wallet first if needed.
    func sell(_ mint: String) {
        Task {
            if wallet == nil { await loadWallet(fresh: true) }
            if let h = wallet?.holdings.first(where: { $0.mint == mint && ($0.kind == "stock" || $0.kind == "meme") }), h.amount > 0 {
                sheet = .sell(h)
            } else {
                show("You don't hold any yet")
            }
        }
    }

    // MARK: Navigation

    func root(_ t: Tab) {
        tab = t
        path.removeAll()
    }

    func push(_ r: Route) { path.append(r) }

    /// Stocks open the Stock page in Invest and the Floor in Ape.
    func openStock(_ mint: String) { push(isApe ? .floor(mint) : .stock(mint)) }

    func toggleMode() {
        Haptic.light()
        mode = isApe ? .invest : .ape
        wallet = nil
        root(tab)
    }

    // MARK: Data

    func index(_ stocks: [Stock]) {
        for s in stocks { stocksByMint[s.mint] = s }
    }

    /// A fill is the whole point of a limit order, so it arrives rather than being discovered:
    /// the user's own channel pushes it and the toast names it the moment it lands.
    func startOrderFeed() {
        guard let channel = auth.me?.channel, !channel.isEmpty else { return }
        OrdersStore.shared.connect(channel: channel) { [weak self] order in
            guard let self else { return }
            let symbol = order.symbol ?? "Your order"
            let img = order.mint.flatMap { self.stocksByMint[$0] }.map { ToastImage(url: $0.logoURL, symbol: $0.symbol, isStock: true) }
            if order.status == "filled" {
                Haptic.success()
                let what = order.fillUsd.map { " · \(Fmt.cash($0))" } ?? ""
                show("\(symbol) order filled\(what)", image: img)
                Task { await self.loadWallet(bustCache: true) }
            } else if order.status == "cancelled" {
                show("\(symbol) order cancelled", image: img)
            }
        }
    }

    func loadWallet(fresh: Bool = true, bustCache: Bool = false) async {
        guard let address = walletAddress else { wallet = nil; return }
        if let w = try? await API.shared.wallet(address, activity: 30, fresh: fresh, bustCache: bustCache) { wallet = w }
    }

    var cashUsd: Double { wallet?.cashUsd ?? 0 }

    /// After /v1/tx says confirmed the fill is visible on the next read: one fresh wallet read, then re-arm live prices.
    func settleWallet() {
        Task {
            await loadWallet(fresh: true, bustCache: true)
            startWalletLive()
        }
    }

    // MARK: Live P&L (Wallet tab on screen)

    private var liveSockets: [String: LiveSocket] = [:]
    private var liveListeners: [Task<Void, Never>] = []

    /// One room per held mint: `stock:<mint>` for stocks (price frames), `<mint>` for memes (trade frames).
    func startWalletLive() {
        stopWalletLive()
        guard let w = wallet else { return }
        for h in w.positions {
            let room = h.kind == "stock" ? "stock:\(h.mint)" : h.mint
            let s = LiveSocket(room: room)
            liveSockets[h.mint] = s
            let mint = h.mint
            liveListeners.append(Task { [weak self] in
                for await ev in s.events {
                    guard let self, case .frames(let frames) = ev else { continue }
                    for f in frames {
                        switch f {
                        case .price(let p) where p.mint == mint: if let px = p.priceUsd { wallet?.apply(price: px, to: mint) }
                        case .trade(let t) where t.mint == mint: if let px = t.priceUsd { wallet?.apply(price: px, to: mint) }
                        default: break
                        }
                    }
                }
            })
            s.start()
        }
    }

    func stopWalletLive() {
        liveListeners.forEach { $0.cancel() }; liveListeners = []
        liveSockets.values.forEach { $0.stop() }; liveSockets = [:]
    }

    func signOut() async {
        Haptic.rigid()
        await auth.logout()
        wallet = nil
        path.removeAll()
        tab = .home
    }

    // MARK: Watchlists

    func isWatching(_ mint: String) -> Bool { watch.contains(mint) }
    func toggleWatch(_ mint: String) {
        let on: Bool
        if let i = watch.firstIndex(of: mint) { watch.remove(at: i); on = false; show("Removed from watchlist") }
        else { watch.append(mint); on = true; show("Watching") }
        Task { try? await API.shared.watch(mint, on: on) }
    }
    /// Server copy wins after sign-in.
    func syncWatchlist() async {
        guard signedIn, let r = try? await API.shared.watchlist() else { return }
        index(r.stocks)
        watch = r.stocks.map(\.mint)
    }
    func isWatchingToken(_ mint: String) -> Bool { tokenWatch.contains(mint) }
    func toggleTokenWatch(_ mint: String) {
        if let i = tokenWatch.firstIndex(of: mint) { tokenWatch.remove(at: i); show("Removed from watchlist") }
        else { tokenWatch.append(mint); show("Added to watchlist") }
    }

    // MARK: Feedback

    func show(_ message: String, error: Bool = false, pending: Bool = false, image: ToastImage? = nil) {
        if error { Haptic.error() }
        toastIsError = error
        toastPending = pending
        toastImage = image
        toast = message
        if pending { toastTask?.cancel(); return }
        toastTask?.cancel()
        toastTask = Task { [error] in
            try? await Task.sleep(for: .seconds(error ? 3.5 : 2.2))
            if !Task.isCancelled { toast = nil }
        }
    }

    // MARK: Trades run behind the sheet

    var tradeInFlight: TradeResume?

    /// Buy now / Sell now: close the sheet, show a spinner toast, execute, then a green toast — or a red one and the sheet comes back.
    func runTrade(_ r: TradeResume, wallet: any PrivySDK.EmbeddedSolanaWallet) {
        guard tradeInFlight == nil else { return }
        tradeInFlight = r
        sheet = nil
        let what = r.side == .buy ? r.store.youGet : Fmt.qty(r.sellQty, symbol: r.asset.symbol)
        let img = ToastImage(url: r.asset.imageURL, symbol: r.asset.symbol, isStock: r.asset.isStock)
        show("\(r.side == .buy ? "Buying" : "Selling") \(what)…", pending: true, image: img)
        Task {
            await r.store.execute(wallet: wallet) { [weak self] in self?.settleWallet() }
            tradeInFlight = nil
            switch r.store.phase {
            case .confirmed:
                Haptic.success()
                show("\(r.side == .buy ? "Bought" : "Sold") \(what)", image: img)
            case .requoted:
                show("Price changed — take a look", error: true, image: img)
                sheet = .resume(r)
            default:
                show(r.store.error ?? "Trade didn't go through. Nothing was charged.", error: true, image: img)
                sheet = .resume(r)
            }
        }
    }

    func copy(_ value: String) {
        Haptic.light()
        UIPasteboard.general.string = value
        show("Copied to clipboard")
    }
}

struct ToastImage: Equatable {
    let url: URL?
    let symbol: String
    let isStock: Bool
}
