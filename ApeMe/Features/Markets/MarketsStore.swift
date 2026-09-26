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
    var tag: String?
    var sort: Sort = .change

    /// Chips come from /collections, in the backend's order. The `memestocks` collection is
    /// GME/AMC-type equities and stays; only its chip reads "Retail favorites".
    func chipTitle(_ c: StockCollection) -> String {
        c.id == "memestocks" ? "Retail favorites" : c.title
    }

    func load(app: AppState) async {
        if stocks.isEmpty {
            let a: StocksResponse? = await API.shared.cached("/stocks?issuer=prestocks")
            let b: StocksResponse? = await API.shared.cached("/stocks?issuer=xstocks,backpack")
            if let a, let b { stocks = a.stocks + b.stocks }
        }
        if collections.isEmpty, let c: CollectionsResponse = await API.shared.cached("/collections") { collections = c.collections }
        do {
            async let a = API.shared.stocks(issuer: "prestocks")
            async let b = API.shared.stocks(issuer: "xstocks,backpack")
            async let c = API.shared.collections()
            let (ra, rb, rc) = try await (a, b, c)
            stocks = ra.stocks + rb.stocks
            collections = rc.collections
            app.index(stocks)
            error = nil
        } catch {
            if stocks.isEmpty { self.error = "Couldn't load markets." }
        }
    }

    func filtered() -> [Stock] {
        let q = query.lowercased()
        var l = stocks.filter { s in
            (tag == nil || (s.tags ?? []).contains(tag!))
            && (q.isEmpty || s.symbol.lowercased().contains(q) || s.name.lowercased().contains(q) || s.mint.lowercased() == q)
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
