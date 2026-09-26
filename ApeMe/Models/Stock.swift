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
}
