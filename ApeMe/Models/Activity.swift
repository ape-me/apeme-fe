import Foundation

struct Activity: Codable, Identifiable, Hashable {
    var id: String { sig }
    let sig: String
    let ts: Int
    let side: Side
    let mint: String
    let symbol: String
    let image: String?
    let stockSymbol: String?
    let amount: Double
    let quote: Double?
    let usd: Double?

    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}
