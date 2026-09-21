import Foundation
import PrivySDK
import Observation

/// One trade: quote on every amount change (debounced), sign with Privy, submit, poll `/v1/tx`.
@Observable @MainActor
final class TradeStore {
    enum Phase: Equatable { case idle, quoting, ready, insufficient, signing, submitting, confirming, confirmed, failed }
    enum Side { case buy, sell }

    let side: Side
    let mint: String            // the stock / meme mint
    let symbol: String
    let priceUsd: Double?       // display price of the asset, for "You get ≈"
    let holding: Holding?       // sell only

    var phase: Phase = .idle
    var quote: Quote?
    var error: String?
    var requestId: String?
    var signature: String?
    var priority: String

    private var debounce: Task<Void, Never>?
    private var lastRequest: String?

    init(side: Side, mint: String, symbol: String, priceUsd: Double?, holding: Holding?, priority: String) {
        self.side = side; self.mint = mint; self.symbol = symbol; self.priceUsd = priceUsd; self.holding = holding; self.priority = priority
    }

    /// Buy: `usd` in dollars. Sell: `rawAmount` in the holding's raw units.
    func requote(usd: Double? = nil, rawAmount: String? = nil, taker: String?, cashUsd: Double) {
        debounce?.cancel()
        quote = nil; error = nil
        guard let taker else { phase = .idle; return }
        let raw: String
        switch side {
        case .buy:
            guard let usd, usd > 0 else { phase = .idle; return }
            if usd > cashUsd { phase = .insufficient; return }
            raw = String(Int64((usd * 1_000_000).rounded()))
        case .sell:
            guard let rawAmount, rawAmount != "0" else { phase = .idle; return }
            raw = rawAmount
        }
        phase = .quoting
        let key = raw + priority
        lastRequest = key
        debounce = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await fetchQuote(raw: raw, taker: taker, key: key)
        }
    }

    private func fetchQuote(raw: String, taker: String, key: String) async {
        do {
            let q = try await API.shared.quote(inputMint: side == .buy ? "usdc" : mint,
                                               outputMint: side == .buy ? mint : "usdc",
                                               amountRaw: raw, taker: taker, priority: priority)
            guard lastRequest == key else { return }
            quote = q; requestId = q.requestId; phase = .ready
        } catch {
            guard lastRequest == key else { return }
            phase = .failed; self.error = Self.message(error)
        }
    }

    /// "You get" — assets for a buy, dollars for a sell.
    var youGet: String {
        guard let q = quote else { return "—" }
        switch side {
        case .sell: return Fmt.usd(q.outUsd)
        case .buy:
            // Exact from the quote; fall back to $ ÷ price if the fields are missing.
            if let d = q.outDecimals, let raw = Double(q.outAmount) {
                return Fmt.qty(raw / pow(10, Double(d)) * (q.multiplier ?? 1), symbol: symbol)
            }
            guard let out = q.outUsd, let p = priceUsd, p > 0 else { return "—" }
            return Fmt.qty(out / p, symbol: symbol)
        }
    }

    // MARK: Execute

    func execute(wallet: any PrivySDKSolanaWallet, taker: String, cashUsd: Double, onConfirmed: @escaping () -> Void) async {
        guard var q = quote else { return }
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
                if status.error == "expired", !retried, let nq = try? await requoteNow(taker: taker) { q = nq; retried = true; continue }
                phase = .failed; error = status.error.map { "Trade failed: \($0)" } ?? "Trade failed."
                return
            } catch APIError.http(410, _) where !retried {
                guard let nq = try? await requoteNow(taker: taker) else { phase = .failed; error = "Quote expired. Try again."; return }
                q = nq; retried = true; continue
            } catch {
                phase = .failed; self.error = Self.message(error); return
            }
        }
    }

    private func requoteNow(taker: String) async throws -> Quote {
        guard let old = quote else { throw APIError.http(410, "quote_expired") }
        let q = try await API.shared.quote(inputMint: old.side == "buy" ? "usdc" : mint, outputMint: old.side == "buy" ? mint : "usdc",
                                           amountRaw: old.inAmount, taker: taker, priority: priority)
        quote = q; return q
    }

    private func poll(_ sig: String) async throws -> TxStatus {
        for _ in 0..<90 {
            let s = try await API.shared.tx(sig)
            if s.status == "confirmed" || s.status == "failed" { return s }
            try await Task.sleep(for: .seconds(1))
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

typealias PrivySDKSolanaWallet = PrivySDK.EmbeddedSolanaWallet
