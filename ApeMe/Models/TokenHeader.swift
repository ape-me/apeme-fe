import Foundation

struct TokenHeader: Codable, Hashable {
    let mint: String
    let symbol: String?
    let name: String?
    let image: String?
    let quoteMint: String
    let launchpad: String
    var phase: Phase
    let createdAt: Int
    var priceQuote: Double?
    var priceUsd: Double?
    var mcapUsd: Double?
    var vol24hUsd: Double?
    var buys24h: Int?
    var sells24h: Int?
    var change24h: Double?
    let taxBps: Int?
    var progressPct: Double?
    var lastTradeAt: Int?
    var vol5mUsd: Double?
    var buys5m: Int?
    var sells5m: Int?
    var vol1hUsd: Double?
    var buys1h: Int?
    var sells1h: Int?
    let change1h: Double?
    let athMcapUsd: Double?
    let holders: Int?
    let top10Pct: Double?
    let devPct: Double?
    let snipersPct: Double?
    let website: String?
    let twitter: String?
    let telegram: String?
    let dexPaid: Bool?
    let dexPaidAt: Int?
    let dexBoosts: Int?
    let creator: String?
    let decimals: Int
    let supply: String?
    let curvePool: String?
    let ammPool: String?
    let uri: String?
    let stock: StockRef

    var displaySymbol: String { (symbol?.isEmpty == false ? symbol : nil) ?? Fmt.short(mint) }
    var displayName: String { (name?.isEmpty == false ? name : nil) ?? displaySymbol }
    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
    var supplyTokens: Double? {
        guard let supply, let raw = Double(supply) else { return nil }
        return raw / pow(10, Double(decimals))
    }
    /// The card view of this token, for the buy sheet and rows.
    var card: TokenCard {
        TokenCard(mint: mint, symbol: symbol, name: name, image: image, quoteMint: quoteMint, launchpad: launchpad,
                  phase: phase, createdAt: createdAt, priceQuote: priceQuote, priceUsd: priceUsd, mcapUsd: mcapUsd,
                  vol24hUsd: vol24hUsd, buys24h: buys24h, sells24h: sells24h, change24h: change24h, taxBps: taxBps,
                  progressPct: progressPct, lastTradeAt: lastTradeAt, vol5mUsd: vol5mUsd, buys5m: buys5m, sells5m: sells5m,
                  vol1hUsd: vol1hUsd, buys1h: buys1h, sells1h: sells1h, change1h: change1h, athMcapUsd: athMcapUsd,
                  holders: holders, top10Pct: top10Pct, devPct: devPct, snipersPct: snipersPct, website: website,
                  twitter: twitter, telegram: telegram, dexPaid: dexPaid, dexPaidAt: dexPaidAt, dexBoosts: dexBoosts)
    }
}
