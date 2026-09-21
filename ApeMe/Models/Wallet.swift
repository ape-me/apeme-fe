import Foundation

/// `GET /v1/wallet/:address`. `holdings[0]` is the cash row (USDC); positions are `stock` / `meme`.
struct Wallet: Codable, Hashable {
    let address: String
    let totalUsd: Double?
    let cashUsd: Double?
    let solUsd: Double?
    let stocksUsd: Double?
    let memesUsd: Double?
    let costUsd: Double?
    let pnlUsd: Double?
    let realizedUsd: Double?
    let pendingSwaps: Int?
    let holdings: [Holding]
    let activity: [Activity]
    let asOf: Int?

    var cash: Holding? { holdings.first { $0.kind == "cash" } }
    var positions: [Holding] { holdings.filter { $0.kind == "stock" || $0.kind == "meme" }.sorted { ($0.valueUsd ?? 0) > ($1.valueUsd ?? 0) } }
    var sol: Holding? { holdings.first { $0.kind == "sol" } }
    var isEmpty: Bool { (cashUsd ?? 0) == 0 && holdings.count <= 1 }
}
