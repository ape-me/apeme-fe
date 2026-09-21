import Foundation

struct Trade: Codable, Identifiable, Hashable {
    var id: String { sig }
    let sig: String
    let ts: Int
    let slot: Int
    let side: Side
    let wallet: String
    let base: Double
    let quote: Double
    let priceQuote: Double
    let priceUsd: Double?
}
