import Foundation

struct Holding: Codable, Identifiable, Hashable {
    var id: String { mint }
    let mint: String
    let kind: String          // "cash" | "sol" | "stock"
    let symbol: String
    let name: String?
    let image: String?
    let amount: Double
    /// Raw on-chain units as a string; what `/v1/swap/quote` takes when selling. Never derive from `amount`.
    let raw: String?
    let decimals: Int?
    var priceUsd: Double?
    var valueUsd: Double?
    let change24h: Double?
    let costUsd: Double?
    var pnlUsd: Double?
    var pnlPct: Double?
    /// Cost per displayed unit, fees excluded. nil for cash / SOL / outside deposits.
    let avgEntryUsd: Double?
    /// Stonks247 fee + rent + issuer fee paid on this stock's buys and sells.
    let feesUsd: Double?

    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}
