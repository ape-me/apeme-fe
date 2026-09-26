import Foundation
import Observation

@Observable @MainActor
final class HomeStore {
    enum InvestTab: String, CaseIterable, Identifiable {
        case preipo, movers, news, explore, watch
        var id: String { rawValue }
        var label: String { switch self { case .preipo: "Pre-IPO"; case .movers: "Movers"; case .news: "News"; case .explore: "Explore"; case .watch: "Watchlist" } }

        /// Watching something is the clearest thing a user ever tells us about what they care
        /// about, so once the list has anything in it, it leads. Empty, it sits at the back.
        static func ordered(watching: Bool) -> [InvestTab] {
            watching ? [.watch, .preipo, .movers, .news, .explore] : [.preipo, .movers, .news, .explore, .watch]
        }
    }

    var preipo: [Stock] = []
    var collections: [StockCollection] = []
    var movers: MoversResponse?
    var watched: [Stock] = []
    var loading = true
    var error: String?
    var investTab: InvestTab = .preipo
    private var pickedFirstTab = false
    var moversSide = 0          // 0 gainers, 1 losers
    var exploreId: String?
    var feed: [NewsItem] = []
    /// How many items at the head of `feed` are about stocks the user holds or watches.
    var ownedCount = 0
    var feedLoading = false
    var feedLoaded = false
    var feedError: String?

    /// The user's own stocks come first; signed out it's simply the newest across the market.
    func loadFeed(app: AppState) async {
        guard !feedLoading else { return }
        feedLoading = true
        defer { feedLoading = false }
        let held = (app.wallet?.positions ?? []).filter { $0.kind == "stock" }.map(\.mint)
        let mints = Array(Set(app.watch + held))
        do {
            // Capped per stock: one name having a loud day used to take the entire feed, so a
            // wallet holding three stocks read as a single-company newspaper.
            let mine = mints.isEmpty ? [] : try await API.shared.news(mints: mints, limit: 12, perStock: 2).items
            let market = try await API.shared.news(limit: 30, perStock: 1).items
            var seen = Set(mine.map(\.id))
            // The user's own stocks lead, and within those a story with a picture leads, so the
            // banner is never a market name sitting above the stocks they actually hold.
            let ownFirst = mine.filter { $0.photoURL != nil } + mine.filter { $0.photoURL == nil }
            feed = ownFirst + market.filter { seen.insert($0.id).inserted }
            ownedCount = ownFirst.count
            feedError = nil
            feedLoaded = true
        } catch {
            if feed.isEmpty { feedError = "Couldn't load the news." }
        }
    }

    func load(app: AppState) async {
        // Home opens on the watchlist for anyone who has one, and only on the first load —
        // after that wherever the user last tapped is theirs to keep.
        if !pickedFirstTab {
            investTab = InvestTab.ordered(watching: !app.watch.isEmpty)[0]
            pickedFirstTab = true
        }
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
    }

    /// Home is the first screen anyone sees, so its prices keep moving. Only the prices are refetched — news and collections will not have moved in
    /// fifteen seconds, and both reads are edge-cached anyway.
    func refreshPrices(app: AppState) async {
        async let p = API.shared.stocks(issuer: "prestocks")
        async let m = API.shared.movers(limit: 5)
        if let pr = try? await p { preipo = pr.stocks; app.index(pr.stocks) }
        if let mr = try? await m { movers = mr }
    }

    func loadWatch(app: AppState) async {
        let mints = app.watch
        guard !mints.isEmpty else { watched = []; return }
        if let r = try? await API.shared.stocks(mints: Array(mints.prefix(50))) {
            watched = r.stocks
            app.index(r.stocks)
        }
    }
}
