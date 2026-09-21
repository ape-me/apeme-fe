import Foundation

struct Stock: Codable, Identifiable, Hashable {
    var id: String { mint }
    let mint: String
    let symbol: String
    let name: String
    let issuer: String
    let category: String
    let tags: [String]?
    let logo: String?
    let priceUsd: Double?
    let change24h: Double?
    let memes: Int
    let marketOpen: Bool
    let multiplier: Double?
    let quoteUsd: Double?
    let markUsd: Double?
    let premiumPct: Double?
    let liquidityUsd: Double?
    let stockVol24hUsd: Double?
    let buys24h: Int?
    let sells24h: Int?
    let heat: Double?
    let launched24h: Int?
    let memeVol24hUsd: Double?
    let wallets24h: Int?
    let king: King?

    var logoURL: URL? { logo.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
    var isPreIPO: Bool { issuer == "prestocks" }
}
