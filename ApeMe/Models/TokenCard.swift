import Foundation

struct TokenCard: Codable, Identifiable, Hashable {
    var id: String { mint }
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
    let vol5mUsd: Double?
    let buys5m: Int?
    let sells5m: Int?
    let vol1hUsd: Double?
    let buys1h: Int?
    let sells1h: Int?
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

    var displaySymbol: String { (symbol?.isEmpty == false ? symbol : nil) ?? Fmt.short(mint) }
    var displayName: String { (name?.isEmpty == false ? name : nil) ?? displaySymbol }
    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
    var isFresh: Bool { Date.now.timeIntervalSince1970 - Double(createdAt) < 3600 }
}
