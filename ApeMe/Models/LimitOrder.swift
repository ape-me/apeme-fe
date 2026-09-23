import Foundation

/// A price you set and walk away from. Jupiter's Trigger program holds the escrow and fills it,
/// so nothing is charged unless it does — and cancelling returns everything.
struct LimitOrder: Codable, Hashable, Identifiable {
    let id: String
    let mint: String
    let symbol: String
    let side: String            // "buy" | "sell"
    let makingRaw: String?
    let takingRaw: String?
    let makingUsd: Double?
    let triggerUsd: Double?
    let status: String          // quoted | open | filled | cancelled | failed
    let signature: String?
    let createdAt: Int?
    let filledAt: Int?
    let fillUsd: Double?
    let feeUsd: Double?
    let rentUsd: Double?
    let error: String?

    var isOpen: Bool { status == "open" }
    var isBuy: Bool { side == "buy" }
    /// What this order has locked up — only buys reserve USDC.
    var escrowUsd: Double? { isBuy ? (makingUsd ?? 0) + (feeUsd ?? 0) + (rentUsd ?? 0) : nil }

    /// How far the trigger sits from where the stock trades now.
    func awayPct(from price: Double?) -> Double? {
        guard let price, price > 0, let t = triggerUsd else { return nil }
        return (t - price) / price * 100
    }
}

/// The quote for an order that hasn't been placed yet.
struct OrderQuote: Codable, Hashable {
    struct Fee: Codable, Hashable {
        let bps: Int?
        let usd: Double?
        let rentUsd: Double?
        let totalUsd: Double?
        let when: String?
        /// Sells are free today — a zero fee line is noise, so the sheet hides it entirely.
        var isFree: Bool { (totalUsd ?? 0) <= 0 }
    }
    let id: String
    let transaction: String
    let side: String
    let symbol: String?
    let escrowRaw: String?
    let takingRaw: String?
    let orderUsd: Double?
    let escrowUsd: Double?
    let triggerUsd: Double?
    let fee: Fee?
}

struct OrdersResponse: Codable { let orders: [LimitOrder] }
struct OrderSubmitResponse: Codable { let status: String? }
struct CancelResponse: Codable { let transaction: String }
