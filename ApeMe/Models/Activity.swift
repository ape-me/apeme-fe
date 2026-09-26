import Foundation

/// One row of `wallet.activity`. `type` drives the copy; `status` the pill.
struct Activity: Codable, Identifiable, Hashable {
    var id: String { sig ?? "\(ts)-\(mint)-\(type ?? "")" }
    let sig: String?
    let ts: Int
    let type: String?          // buy | sell | deposit | withdraw
    let status: String?        // pending | confirmed | failed
    let source: String?        // app | chain
    let side: Side?
    let mint: String
    let symbol: String
    let image: String?
    let amount: Double?
    let quote: Double?
    let usd: Double?
    let feeUsd: Double?
    let from: String?
    let error: String?

    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
    var kind: String { type ?? side?.rawValue ?? "buy" }
    var solscanURL: URL? { sig.flatMap { URL(string: "https://solscan.io/tx/\($0)") } }
}
