import Foundation

struct HistoryPoint: Codable, Hashable, Identifiable {
    var id: Int { t }
    let t: Int
    let price: Double?
    let mark: Double?
}
