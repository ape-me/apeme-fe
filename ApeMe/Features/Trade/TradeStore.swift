import Foundation
import PrivySDK
import Observation

/// One trade: quote on every amount change (debounced), keep it fresh, sign with Privy, submit, poll `/v1/tx`.
/// Fee model: the typed amount is the total that leaves the wallet; fee + rent come out of it.
@Observable @MainActor
final class TradeStore {
    enum Phase: Equatable { case idle, quoting, ready, insufficient, signing, submitting, confirming, confirmed, failed, requoted }
    enum Side { case buy, sell }

    let side: Side
    let mint: String
    let symbol: String
    let priceUsd: Double?
    let holding: Holding?

    var phase: Phase = .idle
    var quote: Quote?
    /// A fresh quote after expiry whose price moved more than 1% — the user has to look again.
    var replacement: Quote?
    var error: String?
    var requestId: String?
    var signature: String?
    var priority: String
    /// Consecutive 422 slippage failures — after two, the sheet suggests a wider tolerance.
    var slippageFails = 0
    /// Per-trade tolerance. nil = the user's setting; raised to the BE's suggestion or to 3% on retry.
    var slippageBps: Int?

    private var debounce: Task<Void, Never>?
    private var expiry: Task<Void, Never>?
    private var lastRequest: String?
    private var lastRaw: String?
    private var taker: String?

    init(side: Side, mint: String, symbol: String, priceUsd: Double?, holding: Holding?, priority: String) {
        self.side = side; self.mint = mint; self.symbol = symbol; self.priceUsd = priceUsd; self.holding = holding; self.priority = priority
    }

    // MARK: Quote

    /// Buy: `usd` in dollars (the total debit). Sell: `rawAmount` in the holding's raw units.
    func requote(usd: Double? = nil, rawAmount: String? = nil, taker: String?, cashUsd: Double) {
        debounce?.cancel(); expiry?.cancel()
        quote = nil; replacement = nil; error = nil
        guard let taker else { phase = .idle; return }
        self.taker = taker
        let raw: String
        switch side {
        case .buy:
            guard let usd, usd > 0 else { phase = .idle; return }
            if usd > cashUsd + 0.000001 { phase = .insufficient; return }
            raw = String(Int64((usd * 1_000_000).rounded()))
        case .sell:
            guard let rawAmount, rawAmount != "0" else { phase = .idle; return }
            if rawAmount == "over" { phase = .insufficient; return }
            raw = rawAmount
        }
        phase = .quoting
        let key = raw + priority
        lastRequest = key; lastRaw = raw
        debounce = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await fetchQuote(raw: raw, key: key)
        }
    }

    private func fetchQuote(raw: String, key: String) async {
        guard let taker else { return }
        do {
            var q = try await API.shared.quote(inputMint: side == .buy ? "usdc" : mint, outputMint: side == .buy ? mint : "usdc",
                                               amountRaw: raw, taker: taker, priority: priority, slippageBps: slippageBps)
            guard lastRequest == key else { return }
            // Thin pool: the BE suggests a wider band than the user's setting — take it for this trade.
            if let sug = q.suggestedSlippageBps, sug > (q.slippageBps ?? 0), slippageBps == nil || sug > slippageBps! {
                slippageBps = sug
                q = try await API.shared.quote(inputMint: side == .buy ? "usdc" : mint, outputMint: side == .buy ? mint : "usdc",
                                               amountRaw: raw, taker: taker, priority: priority, slippageBps: sug)
                guard lastRequest == key else { return }
            }
            quote = q; requestId = q.requestId; phase = .ready
            armExpiry()
        } catch {
            guard lastRequest == key else { return }
            phase = .failed; self.error = Self.message(error)
        }
    }

    /// Quotes live 60 s. Refresh silently 10 s before, so the tx blockhash is still good when the user taps Pay.
    private func armExpiry() {
        expiry?.cancel()
        guard let q = quote, let exp = q.expiresAt else { return }
        let wait = max(1, Double(exp) - Date.now.timeIntervalSince1970 - 10)
        expiry = Task {
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, phase == .ready else { return }
            await refresh()
        }
    }

    /// Also called when the app returns to the foreground.
    func refresh() async {
        guard phase == .ready, let raw = lastRaw, let key = lastRequest else { return }
        await fetchQuote(raw: raw, key: key)
    }

    private var isFresh: Bool {
        guard let exp = quote?.expiresAt else { return true }
        return Double(exp) - Date.now.timeIntervalSince1970 > 3
    }

    // MARK: Display

    var youGet: String {
        guard let q = quote else { return "—" }
        switch side {
        case .sell: return Fmt.usd(q.outUsd)
        case .buy:
            if let d = q.outDecimals, let raw = Double(q.outAmount) {
                return Fmt.qty(raw / pow(10, Double(d)) * (q.multiplier ?? 1), symbol: symbol)
            }
            guard let out = q.outUsd, let p = priceUsd, p > 0 else { return "—" }
            return Fmt.qty(out / p, symbol: symbol)
        }
    }

    // MARK: Execute

    func execute(wallet: any EmbeddedSolanaWallet, onConfirmed: @escaping () -> Void) async {
        guard var q = quote else { return }
        expiry?.cancel()
        // Stale locally: re-quote first, and only auto-continue when the price barely moved.
        if !isFresh {
            guard let nq = try? await requoteNow() else { phase = .failed; error = "Quote expired. Try again."; return }
            quote = nq; requestId = nq.requestId
            if !Self.within1pct(q, nq) { replacement = nq; phase = .requoted; return }
            q = nq; quote = nq
        }
        var retried = false
        while true {
            do {
                phase = .signing
                let signed = try await SolanaTx.sign(q.transaction, with: wallet)
                phase = .submitting
                let r = try await API.shared.submit(requestId: q.requestId, signedTransaction: signed)
                signature = r.signature; requestId = q.requestId
                phase = .confirming
                let status = try await poll(r.signature)
                if status.status == "confirmed" { phase = .confirmed; onConfirmed(); return }
                if status.error == "expired", !retried, let nq = try? await requoteNow() {
                    if !Self.within1pct(q, nq) { replacement = nq; phase = .requoted; return }
                    q = nq; quote = nq; retried = true; continue
                }
                phase = .failed; error = "Trade didn't go through. Nothing was charged." + (status.error.map { " (\($0))" } ?? "")
                return
            } catch APIError.http(410, _) where !retried {
                guard let nq = try? await requoteNow() else { phase = .failed; error = "Quote expired. Try again."; return }
                if !Self.within1pct(q, nq) { replacement = nq; phase = .requoted; return }
                q = nq; quote = nq; retried = true; continue
            } catch APIError.http(422, let msg) where msg.lowercased().contains("slippage") {
                // Re-quote in place so Review already shows the new numbers; Try again pays with them.
                slippageFails += 1
                if let nq = try? await requoteNow() { quote = nq; requestId = nq.requestId; armExpiry() }
                phase = .failed; error = "Price moved. Nothing was charged."; return
            } catch {
                phase = .failed; self.error = Self.message(error); return
            }
        }
    }

    /// "Try again" on Review: make sure the quote is fresh, then pay — never back to the amount step.
    func retry(wallet: any EmbeddedSolanaWallet, onConfirmed: @escaping () -> Void) async {
        error = nil
        if quote == nil || !isFresh {
            guard let raw = lastRaw, let key = lastRequest else { return }
            phase = .quoting; lastRequest = key
            await fetchQuote(raw: raw, key: key)
            guard phase == .ready else { return }
        } else { phase = .ready }
        await execute(wallet: wallet, onConfirmed: onConfirmed)
    }

    /// "Retry with 3%": widen the band for this trade only, re-quote, pay.
    func retryWider(wallet: any EmbeddedSolanaWallet, onConfirmed: @escaping () -> Void) async {
        slippageBps = max(300, slippageBps ?? 0)
        quote = nil
        await retry(wallet: wallet, onConfirmed: onConfirmed)
    }

    /// User looked at the new numbers and accepted them.
    func acceptReplacement(wallet: any EmbeddedSolanaWallet, onConfirmed: @escaping () -> Void) async {
        guard let nq = replacement else { return }
        quote = nq; replacement = nil; phase = .ready
        await execute(wallet: wallet, onConfirmed: onConfirmed)
    }

    private static func within1pct(_ a: Quote, _ b: Quote) -> Bool {
        guard let x = Double(a.outAmount), let y = Double(b.outAmount), x > 0 else { return false }
        return abs(y - x) / x <= 0.01
    }

    private func requoteNow() async throws -> Quote {
        guard let old = quote, let taker else { throw APIError.http(410, "quote_expired") }
        return try await API.shared.quote(inputMint: old.side == "buy" ? "usdc" : mint, outputMint: old.side == "buy" ? mint : "usdc",
                                          amountRaw: old.inAmount, taker: taker, priority: priority, slippageBps: slippageBps)
    }

    /// Every 2 s: the BE rebroadcasts the signed tx on each poll while it's still pending.
    private func poll(_ sig: String) async throws -> TxStatus {
        for _ in 0..<45 {
            let s = try await API.shared.tx(sig)
            if s.status == "confirmed" || s.status == "failed" { return s }
            try await Task.sleep(for: .seconds(2))
        }
        return TxStatus(signature: sig, status: "failed", slot: nil, confirmations: nil, error: "timeout")
    }

    static func message(_ error: Error) -> String {
        if case APIError.http(let code, let msg) = error {
            let m = msg.lowercased()
            if m.contains("slippage") { return "Price moved. Try again." }
            if m.contains("insufficient") { return "Not enough cash. Deposit first." }
            if m.contains("amount_too_small") { return "Amount too small." }
            if m.contains("no_route") { return "No route for this trade right now." }
            if m.contains("invite_required") { return "Enter your invite code first." }
            if code == 429 { return "Too many trades this hour. Take a breath." }
            if m.contains("not one of your wallets") { return "This wallet isn't linked to your account yet. \(msg)" }
            return msg
        }
        return "No connection. Try again."
    }
}
