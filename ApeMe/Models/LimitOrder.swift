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
    let status: String          // quoted | open | partial | filled | cancelled | failed
    let signature: String?
    let createdAt: Int?
    let filledAt: Int?
    let fillUsd: Double?
    let feeUsd: Double?
    let rentUsd: Double?
    let error: String?
    let expiresAt: Int?
    /// Jupiter fills in pieces. Whichever of these the BE sends, `filledFraction` uses it.
    let filledUsd: Double?
    let filledPct: Double?
    let remainingMakingRaw: String?
    let remainingTakingRaw: String?

    /// A partly filled order is still working, so it belongs with the open ones.
    var isOpen: Bool { status == "open" || status == "partial" }
    var isBuy: Bool { side == "buy" }

    /// How much of the order has been taken, 0…1. nil when the BE says nothing about it.
    var filledFraction: Double? {
        if let p = filledPct { return min(1, max(0, p > 1 ? p / 100 : p)) }
        if let m = makingUsd, m > 0, let f = filledUsd ?? (isOpen ? nil : fillUsd) {
            return min(1, max(0, f / m))
        }
        if let making = makingRaw.flatMap(Double.init), making > 0,
           let left = remainingMakingRaw.flatMap(Double.init) {
            return min(1, max(0, 1 - left / making))
        }
        return nil
    }
    /// Partly filled and still working — the row has to say so rather than read as done.
    var isPartial: Bool {
        guard isOpen, let f = filledFraction else { return false }
        return f > 0.001 && f < 0.999
    }
    var filledUsdValue: Double? {
        if let filledUsd { return filledUsd }
        guard let f = filledFraction, let m = makingUsd else { return isOpen ? nil : fillUsd }
        return m * f
    }
    /// Past its deadline but not closed. Until we have proof Jupiter returns the money on its
    /// own, the row treats this as "still yours, cancel to get it back".
    var isExpired: Bool {
        guard isOpen, let e = expiresAt else { return false }
        return Double(e) <= Date.now.timeIntervalSince1970
    }

    /// What this order has locked up — only buys reserve USDC, and only the unfilled part.
    var escrowUsd: Double? {
        guard isBuy else { return nil }
        let left = (makingUsd ?? 0) * (1 - (filledFraction ?? 0))
        return left + (feeUsd ?? 0) + (rentUsd ?? 0)
    }

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
