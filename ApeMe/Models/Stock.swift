import Foundation

struct Stock: Codable, Identifiable, Hashable {
    var id: String { mint }
    let mint: String
    let symbol: String
    let name: String
    let issuer: String
    let category: String
    let tags: [String]?
    /// The real-world ticker. AAPLx and AAPL both carry "AAPL", so search finds either from
    /// what the user actually types.
    let underlying: String?
    /// The issuer suspended trading in the underlying. Swap and order calls 409 on these.
    let halted: Bool?
    let logo: String?
    var priceUsd: Double?
    var decimals: Int?
    var change24h: Double?
    let marketOpen: Bool
    let multiplier: Double?
    let quoteUsd: Double?
    var markUsd: Double?
    var premiumPct: Double?
    let liquidityUsd: Double?
    let stockVol24hUsd: Double?
    let buys24h: Int?
    let sells24h: Int?

    var logoURL: URL? { logo.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
    var isPreIPO: Bool { issuer == "prestocks" }
    var isOndo: Bool { issuer == "ondo" }
    /// Ondo fills off-pool, so its `liquidityUsd` is a few hundred dollars that has nothing to do
    /// with what you can trade, and `buys24h`/`sells24h` are always zero. Depth still works.
    var showsPoolStats: Bool { !isOndo }
    var isHalted: Bool { halted == true }
    /// Crypto and earn ignore the US equity session entirely; it says nothing about them.
    var followsMarketHours: Bool { category != "crypto" && category != "earn" }
    var isEarn: Bool { category == "earn" }

    /// Symbol, name or the real ticker — the user should not have to know about the x suffix.
    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        if q.isEmpty { return true }
        if mint.lowercased() == q { return true }
        return symbol.lowercased().contains(q)
            || name.lowercased().contains(q)
            || (underlying?.lowercased().contains(q) ?? false)
    }
}
