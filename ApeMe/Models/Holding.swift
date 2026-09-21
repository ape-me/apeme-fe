import Foundation

struct Holding: Codable, Identifiable, Hashable {
    var id: String { mint }
    let mint: String
    let kind: String          // "sol" | "stock" | "meme"
    let symbol: String
    let name: String?
    let image: String?
    let quoteSymbol: String?
    let amount: Double
    let priceUsd: Double?
    let valueUsd: Double?
    let change24h: Double?
    let costUsd: Double?
    let pnlUsd: Double?
    let pnlPct: Double?

    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}
