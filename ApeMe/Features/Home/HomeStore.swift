import Foundation
import Observation

@Observable @MainActor
final class HomeStore {
    enum InvestTab: String, CaseIterable, Identifiable {
        case preipo, movers, explore, watch, news
        var id: String { rawValue }
        var label: String { switch self { case .preipo: "Pre-IPO"; case .movers: "Movers"; case .explore: "Explore"; case .watch: "Watchlist"; case .news: "News" } }
    }
    enum ApeTab: String, CaseIterable, Identifiable {
        case preipo, new, kings
        var id: String { rawValue }
        var label: String { switch self { case .preipo: "Pre-IPO"; case .new: "New launches"; case .kings: "Kings" } }
    }

    var preipo: [Stock] = []
    var collections: [StockCollection] = []
    var movers: MoversResponse?
    var ticker: [TickerItem] = []
    var newTokens: [TokenCard] = []
    var watched: [Stock] = []
    var loading = true
    var error: String?
    var investTab: InvestTab = .preipo
    var apeTab: ApeTab = .preipo
    var moversSide = 0          // 0 gainers, 1 losers
    var exploreId: String?
    var flashes: [String: Flash] = [:]
    var socketStatus: LiveSocket.Status = .connecting
    /// One curated headline per stock for the strip, and the full feed for the News tab.
    var headlines: [NewsItem] = []
    var headlinesLoading = true
    var feed: [NewsItem] = []
    var feedLoading = false
    var feedLoaded = false
    var feedError: String?

    private var socket: LiveSocket?
    private var listener: Task<Void, Never>?
    private var stamp = 0

    /// The user's own stocks come first; signed out it's simply the newest across the market.
    func loadFeed(app: AppState) async {
        guard !feedLoading else { return }
        feedLoading = true
        defer { feedLoading = false }
        let held = (app.wallet?.positions ?? []).filter { $0.kind == "stock" }.map(\.mint)
        let mints = Array(Set(app.watch + held))
        do {
            feed = try await API.shared.news(mints: mints, limit: 30).items
            feedError = nil
            feedLoaded = true
        } catch {
            if feed.isEmpty { feedError = "Couldn't load the news." }
        }
    }

    func load(app: AppState) async {
        // Paint whatever is cached first, then refresh.
        if preipo.isEmpty, let c: StocksResponse = await API.shared.cached("/stocks?issuer=prestocks") {
            preipo = c.stocks; loading = false
        }
        async let p = API.shared.stocks(issuer: "prestocks")
        async let c = API.shared.collections()
        async let m = API.shared.movers(limit: 5)
        do {
            let (pr, cr, mr) = try await (p, c, m)
            preipo = pr.stocks
            collections = cr.collections
            movers = mr
            app.index(pr.stocks)
            for col in cr.collections { app.index(col.stocks ?? []) }
            if exploreId == nil { exploreId = cr.collections.first(where: { $0.id != "preipo" })?.id }
            error = nil
            app.online = true
        } catch {
            app.online = false
            if preipo.isEmpty { self.error = "Markets are taking a moment" }
        }
        loading = false
        if let t = try? await API.shared.ticker(memes: 10, stonks: 1) { ticker = t.tokens }
        if let h = try? await API.shared.newsTicker() { headlines = h.items }
        headlinesLoading = false
    }

    func loadWatch(app: AppState) async {
        let mints = app.watch
        guard !mints.isEmpty else { watched = []; return }
        if let r = try? await API.shared.stocks(mints: Array(mints.prefix(50))) {
            watched = r.stocks
            app.index(r.stocks)
        }
    }

    func loadNew(app: AppState) async {
        if let r = try? await API.shared.newTokens(limit: 30) { newTokens = r.tokens }
        connectFloor(app: app)
    }

    var kings: [Stock] {
        var seen = Set<String>()
        let all = preipo + collections.flatMap { $0.stocks ?? [] }
        return all.filter { $0.king != nil && seen.insert($0.mint).inserted }
            .sorted { ($0.king?.vol24hUsd ?? 0) > ($1.king?.vol24hUsd ?? 0) }
            .prefix(25).map { $0 }
    }

    var preipoByHeat: [Stock] { preipo.sorted { ($0.heat ?? 0) > ($1.heat ?? 0) } }

    private func connectFloor(app: AppState) {
        guard socket == nil else { return }
        let s = LiveSocket(room: "floor")
        socket = s
        listener = Task { [weak self] in
            for await ev in s.events {
                guard let self else { return }
                switch ev {
                case .status(let st): socketStatus = st
                case .frames(let frames):
                    for f in frames {
                        switch f {
                        case .trade(let t):
                            if newTokens.contains(where: { $0.mint == t.mint }) {
                                stamp += 1; flashes[t.mint] = Flash(side: t.side, stamp: stamp)
                            }
                        case .token(let mint, let event) where event == "created":
                            Task { await self.insertNew(mint) }
                        default: break
                        }
                    }
                }
            }
        }
        s.start()
    }

    private func insertNew(_ mint: String) async {
        try? await Task.sleep(for: .seconds(1.5))
        guard let h = try? await API.shared.token(mint, fresh: true), !newTokens.contains(where: { $0.mint == mint }) else { return }
        newTokens.insert(h.card, at: 0)
        stamp += 1; flashes[mint] = Flash(side: .buy, stamp: stamp)
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        socket?.stop(); socket = nil
    }
}
