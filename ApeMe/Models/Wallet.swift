import Foundation

struct Wallet: Codable, Hashable {
    let address: String
    let totalUsd: Double?
    let solUsd: Double?
    let stocksUsd: Double?
    let memesUsd: Double?
    let costUsd: Double?
    let pnlUsd: Double?
    let realizedUsd: Double?
    let holdings: [Holding]
    let activity: [Activity]
    let asOf: Int?
}
