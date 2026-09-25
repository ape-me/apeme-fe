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
    let status: String          // quoted | open | partial | expired | filled | cancelled | failed
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

    /// Still holding the user's money, so it belongs with the open ones. An expired order is
    /// not finished: Jupiter keeps it in its active list and the escrow only comes back on a
    /// cancel, which we confirmed against the program rather than the docs.
    var isOpen: Bool { status == "open" || status == "partial" || status == "expired" }
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
    /// Past its deadline and still holding the escrow. Either the backend says so outright, or
    /// the deadline has passed and it has not closed.
    /// Orders no longer expire. This only catches rows from before that change, which still hold
    /// money until cancelled, so the Reclaim path stays for them and nothing new reaches it.
    var isExpired: Bool { status == "expired" }

    /// Needs the user to do something before the money comes back.
    var needsReclaim: Bool { isExpired }

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
    /// Sells only: what lands in the wallet after the 1% fee. The order is sized net of the fee,
    /// so the trigger is the real fill price. Null on buys.
    let proceedsUsd: Double?
    /// Always null now: orders rest until filled or cancelled.
    let expiresAt: Int?
}

struct OrdersResponse: Codable { let orders: [LimitOrder] }
struct OrderSubmitResponse: Codable { let status: String? }
struct CancelResponse: Codable { let transaction: String }
