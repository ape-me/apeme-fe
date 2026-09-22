import Foundation

struct Holding: Codable, Identifiable, Hashable {
    var id: String { mint }
    let mint: String
    let kind: String          // "cash" | "sol" | "stock" | "meme"
    let symbol: String
    let name: String?
    let image: String?
    let quoteSymbol: String?
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

    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}
