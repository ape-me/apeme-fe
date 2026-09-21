import Foundation

struct StockCollection: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let tagline: String?
    let stocks: [Stock]?
}
