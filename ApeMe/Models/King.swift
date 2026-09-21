import Foundation

/// The most traded token on a stock today.
struct King: Codable, Hashable {
    let mint: String
    let symbol: String
    let image: String?
    let vol24hUsd: Double
    let priceUsd: Double?
    let mcapUsd: Double?
    let change24h: Double?
    let phase: Phase?
    let progressPct: Double?
    let launchpad: String?

    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}
