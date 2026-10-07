import Foundation

/// A ready-made set of stocks bought in one tap, equal weight. There is no contract behind it: a
/// basket is several of our ordinary swaps, and the tokens land in the user's wallet like any
/// other buy. The list is whatever the backend returns — never a hard-coded set.
struct Basket: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let tagline: String?
    let stockCount: Int?
    let logos: [String]?
    /// Null when there is no history to measure, e.g. a basket of pre-IPO names.
    let return1y: Double?
    /// "1Y", or "since Sep 27" where the history is shorter than a year.
    let returnLabel: String?
    let minUsd: Double?
    let tradable: Bool?

    var logoURLs: [URL] { (logos ?? []).prefix(5).compactMap(URL.init(string:)) }
    var canTrade: Bool { tradable ?? true }
}

struct BasketsResponse: Codable { let baskets: [Basket]; let asOf: Int? }

struct BasketDetail: Codable, Hashable {
    struct ChartPoint: Codable, Hashable { let t: Int; let value: Double }
    struct Chart: Codable, Hashable { let range: String?; let points: [ChartPoint] }
    struct Extreme: Codable, Hashable { let symbol: String; let return1y: Double? }
    struct Links: Codable, Hashable {
        let issuer: String?
        let solscan: String?
        /// Null for pre-IPO names — there is no listing to point at.
        let yahoo: String?
    }
    struct Leg: Codable, Hashable, Identifiable {
        let weight: Double?
        let return1y: Double?
        /// One line on why this stock is in the basket.
        let why: String?
        let links: Links?
        /// The same Stock the catalog serves, so the stock row renders it unchanged.
        let stock: Stock
        var id: String { stock.mint }
    }
    struct Performance: Codable, Hashable {
        struct Benchmark: Codable, Hashable {
            let name: String?
            let ticker: String?
            let ranges: [String: Double?]?
            let points: [ChartPoint]?
        }
        /// 1M / 3M / 6M / 1Y. A null range means there is not enough history for it.
        let ranges: [String: Double?]?
        let benchmark: Benchmark?
    }
    struct Risk: Codable, Hashable {
        struct Drawdown: Codable, Hashable { let pct: Double?; let from: Int?; let to: Int? }
        struct Day: Codable, Hashable { let pct: Double?; let t: Int? }
        /// Low / Medium / High.
        let level: String?
        let volatilityPct: Double?
        let maxDrawdown: Drawdown?
        let worstDay: Day?
        let bestDay: Day?
        let notes: [String]?
    }
    struct Rebalance: Codable, Hashable { let available: Bool?; let note: String? }

    let id: String
    let name: String
    let tagline: String?
    let description: String?
    let stockCount: Int?
    let logos: [String]?
    let return1y: Double?
    let returnLabel: String?
    let minUsd: Double?
    let feeBps: Int?
    let tradable: Bool?
    /// The value of $100 over the period. Null when there is nothing to chart.
    let chart: Chart?
    let best: Extreme?
    let worst: Extreme?
    let stocks: [Leg]
    /// Two short paragraphs.
    let about: [String]?
    let performance: Performance?
    /// Null when there is not enough history to measure.
    let risk: Risk?
    let rebalance: Rebalance?

    var canTrade: Bool { tradable ?? true }
    var feeRate: Double { Double(feeBps ?? 100) / 10_000 }
}

/// One Jupiter swap per stock. Each leg is exactly a swap quote, signed exactly like one.
struct BasketQuote: Codable, Hashable {
    struct Leg: Codable, Hashable, Identifiable {
        let weight: Double?
        let requestId: String
        let symbol: String?
        let inUsd: Double?
        let outUsd: Double?
        let outAmount: String?
        let priceImpactPct: Double?
        let fee: Quote.Fee?
        let transaction: String
        let expiresAt: Int?
        var id: String { requestId }
    }
    let orderId: String
    let basketId: String
    let side: String
    let amountUsd: Double?
    let feeUsd: Double?
    /// The earliest leg's expiry — sign everything before this.
    let expiresAt: Int?
    let legs: [Leg]

    var isSell: Bool { side == "sell" }
    var totalOutUsd: Double { legs.compactMap(\.outUsd).reduce(0, +) }
}

struct BasketSubmitResponse: Codable, Hashable {
    struct Leg: Codable, Hashable, Identifiable {
        let requestId: String
        let status: String?
        let signature: String?
        let error: String?
        var id: String { requestId }
        var landed: Bool { status == "confirmed" }
    }
    let orderId: String
    /// done, partial or failed. On partial the failed legs' USDC never left the wallet.
    let status: String
    let legs: [Leg]
}

struct BasketPosition: Codable, Hashable, Identifiable {
    struct Holding: Codable, Hashable, Identifiable {
        let mint: String
        let symbol: String
        let logo: String?
        let amount: Double?
        let valueUsd: Double?
        var id: String { mint }
        var logoURL: URL? { logo.flatMap(URL.init(string:)) }
    }
    let basketId: String
    let name: String
    /// Fees included. P&L is against this and is the backend's — never recomputed here.
    let paidUsd: Double?
    let valueUsd: Double?
    let pnlUsd: Double?
    let pnlPct: Double?
    let openedAt: Int?
    /// Always false for now; the toggle renders disabled with "Coming soon".
    let rebalance: Bool?
    let stocks: [Holding]
    var id: String { basketId }
}

struct BasketPositionsResponse: Codable { let positions: [BasketPosition] }
