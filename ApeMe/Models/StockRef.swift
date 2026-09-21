import Foundation

/// The stock embedded in a token header. `quoteUsd` converts candle values to USD.
struct StockRef: Codable, Hashable {
    let mint: String
    let symbol: String
    let name: String
    let priceUsd: Double?
    let change24h: Double?
    let marketOpen: Bool
    let multiplier: Double?
    let quoteUsd: Double?
}
