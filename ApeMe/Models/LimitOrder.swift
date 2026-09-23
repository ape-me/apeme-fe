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
    let expiresAt: Int?

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
    /// Jupiter's order deposit — returned in SOL when the order closes, filled or cancelled.
    let depositUsd: Double?
    /// The token account, a one-time cost the first time this stonk is held. 0 after that.
    let accountUsd: Double?
    /// depositUsd + accountUsd, each rounded on its own so the rows always add to the total.
    let costUsd: Double?
    /// escrowUsd + costUsd — what actually leaves the wallet to place the order.
    let totalUsd: Double?
    let triggerUsd: Double?
    let fee: Fee?
    /// Unix seconds. Jupiter drops the order at this point if it has not filled.
    let expiresAt: Int?
}

struct OrdersResponse: Codable { let orders: [LimitOrder] }
struct OrderSubmitResponse: Codable { let status: String? }
struct CancelResponse: Codable { let transaction: String }
