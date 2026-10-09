import Foundation

/// `GET /v1/wallet/:address`. `holdings[0]` is the cash row (USDC); positions are stocks.
struct Wallet: Codable, Hashable {
    let address: String
    var totalUsd: Double?
    let cashUsd: Double?
    let solUsd: Double?
    var stocksUsd: Double?
    let costUsd: Double?
    /// Total fees paid across the wallet.
    let feesUsd: Double?
    var pnlUsd: Double?
    let realizedUsd: Double?
    let pendingSwaps: Int?
    var holdings: [Holding]
    let activity: [Activity]
    let asOf: Int?

    var cash: Holding? { holdings.first { $0.kind == "cash" } }
    /// A sold position leaves a few raw units behind (rounding on the sell side). That is dust,
    /// not a holding: anything worth under a cent is hidden from every list.
    var positions: [Holding] {
        holdings
            .filter { $0.kind == "stock" && !$0.isDust }
            .sorted { ($0.valueUsd ?? 0) > ($1.valueUsd ?? 0) }
    }
    var sol: Holding? { holdings.first { $0.kind == "sol" } }

    /// Stocks held outside any basket. A basket is one position to the user, so what it holds
    /// comes off the plain list; AAPLx bought on its own and AAPLx inside Mag 7 are not the same
    /// thing twice. A remainder's cost basis is unknown, so it carries no P&L.
    func positions(outside baskets: [BasketPosition]) -> [Holding] {
        var inBaskets: [String: Double] = [:]
        for b in baskets { for h in b.stocks { inBaskets[h.mint, default: 0] += h.amount ?? 0 } }
        return positions.compactMap { h in
            guard let held = inBaskets[h.mint], held > 0 else { return h }
            var rest = h
            rest.amount = max(0, h.amount - held)
            // A fill lands a hair above its quote and the basket records the quote, so a sliver
            // of every stock reads as held "outside" the basket. It is the basket's.
            if rest.amount <= held * 0.02 { return nil }
            rest.valueUsd = h.priceUsd.map { $0 * rest.amount } ?? h.valueUsd.map { $0 * rest.amount / max(h.amount, 1e-12) }
            rest.pnlUsd = nil; rest.pnlPct = nil
            return rest.isDust ? nil : rest
        }
    }
    var isEmpty: Bool { (cashUsd ?? 0) == 0 && holdings.count <= 1 }
    /// Sum of cost for positions bought through Stonks247. Outside deposits (costUsd nil) don't count.
    var investedUsd: Double { positions.compactMap(\.costUsd).reduce(0, +) }
    var positionsUsd: Double { positions.compactMap(\.valueUsd).reduce(0, +) }

    /// A live price tick for one held mint. Cash never moves; cost never moves without a trade.
    mutating func apply(price: Double, to mint: String) {
        guard let i = holdings.firstIndex(where: { $0.mint == mint && $0.kind == "stock" }) else { return }
        var h = holdings[i]
        h.priceUsd = price
        h.valueUsd = h.amount * price
        if let c = h.costUsd, c > 0 { h.pnlUsd = h.valueUsd! - c; h.pnlPct = h.pnlUsd! / c * 100 }
        holdings[i] = h
        stocksUsd = holdings.filter { $0.kind == "stock" }.compactMap(\.valueUsd).reduce(0, +)
        totalUsd = (cashUsd ?? 0) + (solUsd ?? 0) + (stocksUsd ?? 0)
        let withCost = positions.filter { $0.costUsd != nil }
        pnlUsd = withCost.isEmpty ? nil : withCost.compactMap(\.pnlUsd).reduce(0, +)
    }
}
