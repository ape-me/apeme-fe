import Foundation

struct TickerItem: Codable, Identifiable, Hashable {
    let id: String
    let kind: String          // "meme" | "stonk"
    let label: String
    let logo: String?
    let change24h: Double?
    let price: Double?
}
