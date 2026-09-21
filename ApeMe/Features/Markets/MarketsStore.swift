import Foundation
import Observation

@Observable @MainActor
final class MarketsStore {
    enum Issuer: String, CaseIterable, Identifiable {
        case all, prestocks, xstocks, backpack
        var id: String { rawValue }
        var label: String { switch self { case .all: "All"; case .prestocks: "Pre-IPO"; case .xstocks: "xStocks"; case .backpack: "Backpack" } }
    }
    enum Sort: String, CaseIterable, Identifiable {
        case change, volume, premium, heat
        var id: String { rawValue }
        func label(ape: Bool) -> String {
            switch self {
            case .change: "24h change"
            case .volume: ape ? "Meme volume" : "Trading volume"
            case .premium: "Premium to fair value"
            case .heat: "Heat"
            }
        }
        static func options(ape: Bool) -> [Sort] { ape ? [.heat, .volume, .change] : [.change, .volume, .premium] }
    }

    var stocks: [Stock] = []
    var error: String?
    var query = ""
    var issuer: Issuer = .all
    var tag: String?
    var sort: Sort = .change

    var tags: [String] {
        var seen = Set<String>()
        return stocks.flatMap { $0.tags ?? [] }.filter { seen.insert($0).inserted }
    }

    static func tagName(_ t: String) -> String {
        [ "preipo": "Pre-IPO", "ai": "AI", "mag7": "Big Tech", "crypto-stocks": "Crypto stocks", "memestocks": "Meme stocks",
          "prediction": "Bets & markets", "defense": "Defense", "health": "Health", "etf": "ETFs" ][t] ?? t
    }

    func load(app: AppState) async {
        if stocks.isEmpty {
            let a: StocksResponse? = await API.shared.cached("/stocks?issuer=prestocks")
            let b: StocksResponse? = await API.shared.cached("/stocks?issuer=xstocks,backpack")
            if let a, let b { stocks = a.stocks + b.stocks }
        }
        do {
            async let a = API.shared.stocks(issuer: "prestocks")
            async let b = API.shared.stocks(issuer: "xstocks,backpack")
            let (ra, rb) = try await (a, b)
            stocks = ra.stocks + rb.stocks
            app.index(stocks)
            error = nil
        } catch {
            if stocks.isEmpty { self.error = "Couldn't load markets." }
        }
    }

    func filtered(ape: Bool) -> [Stock] {
        let q = query.lowercased()
        var l = stocks.filter { s in
            (issuer == .all || s.issuer == issuer.rawValue)
            && (tag == nil || (s.tags ?? []).contains(tag!))
            && (q.isEmpty || s.symbol.lowercased().contains(q) || s.name.lowercased().contains(q) || s.mint.lowercased() == q)
        }
        l.sort { a, b in
            switch sort {
            case .change: (a.change24h ?? 0) > (b.change24h ?? 0)
            case .volume: ape ? (a.memeVol24hUsd ?? 0) > (b.memeVol24hUsd ?? 0) : (a.stockVol24hUsd ?? 0) > (b.stockVol24hUsd ?? 0)
            case .premium: abs(a.premiumPct ?? 0) > abs(b.premiumPct ?? 0)
            case .heat: (a.heat ?? 0) > (b.heat ?? 0)
            }
        }
        return l
    }
}
