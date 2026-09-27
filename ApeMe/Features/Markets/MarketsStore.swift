import Foundation
import Observation

@Observable @MainActor
final class MarketsStore {
    enum Sort: String, CaseIterable, Identifiable {
        case change, volume, premium
        var id: String { rawValue }
        var label: String {
            switch self {
            case .change: "24h change"
            case .volume: "Trading volume"
            case .premium: "Premium to fair value"
            }
        }
    }

    var stocks: [Stock] = []
    var collections: [StockCollection] = []
    var error: String?
    var query = ""
    /// Everything on every tab trades through the same swap and order calls — the tab only
    /// decides which list is fetched.
    enum Category: String, CaseIterable, Identifiable {
        case stocks, crypto, earn
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        /// nil is the default deduped list.
        var param: String? { self == .stocks ? nil : rawValue }
    }
    var category: Category = .stocks
    private var lists: [Category: [Stock]] = [:]
    var tag: String?
    var sort: Sort = .change

    /// Chips come from /collections, in the backend's order. The `memestocks` collection is
    /// GME/AMC-type equities and stays; only its chip reads "Retail favorites".
    func chipTitle(_ c: StockCollection) -> String {
        c.id == "memestocks" ? "Retail favorites" : c.title
    }

    /// Sector tags arrive as slugs, and capitalising a slug gives "Defi" and "L1". These are
    /// names, so they are spelled the way the people who use them spell them.
    func groupTitle(_ tag: String) -> String {
        switch tag {
        case "defi": "DeFi"
        case "l1": "L1s"
        case "majors": "Majors"
        case "memes": "Memes"
        case "solana": "Solana"
        case "earn": "Earn"
        default: tag.capitalizedFirst
        }
    }

    func load(app: AppState) async {
        let cat = category
        if stocks.isEmpty, let cached: StocksResponse = await API.shared.cached(cat.param.map { "/stocks?category=\($0)" } ?? "/stocks") {
            stocks = cached.stocks
        }
        if collections.isEmpty, let c: CollectionsResponse = await API.shared.cached("/collections") { collections = c.collections }
        do {
            async let a = API.shared.stocks(category: cat.param)
            async let c = API.shared.collections()
            let (ra, rc) = try await (a, c)
            guard cat == category else { return }
            lists[cat] = ra.stocks
            stocks = ra.stocks
            collections = rc.collections
            app.index(ra.stocks)
            error = nil
        } catch {
            if stocks.isEmpty { self.error = "Couldn't load markets." }
        }
    }

    /// Crypto rows carry their sector in `tags`; when the BE sends none, there is nothing to
    /// group by and the list stays flat.
    var groups: [String] {
        Array(Set(stocks.flatMap { $0.tags ?? [] })).sorted()
    }

    /// Switching tabs paints whatever was already fetched, then refreshes.
    func select(_ c: Category, app: AppState) {
        guard c != category else { return }
        category = c
        tag = nil
        stocks = lists[c] ?? []
        Task { await load(app: app) }
    }

    func filtered() -> [Stock] {
        let q = query.lowercased()
        var l = stocks.filter { s in
            (tag == nil || (s.tags ?? []).contains(tag!)) && s.matches(q)
        }
        l.sort { a, b in
            switch sort {
            case .change: (a.change24h ?? 0) > (b.change24h ?? 0)
            case .volume: (a.stockVol24hUsd ?? 0) > (b.stockVol24hUsd ?? 0)
            case .premium: abs(a.premiumPct ?? 0) > abs(b.premiumPct ?? 0)
            }
        }
        return l
    }
}
