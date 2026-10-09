import Foundation
import Observation
import PrivySDK

/// The list and one detail at a time. Both are public, cached 60s on the backend.
@Observable @MainActor
final class BasketsStore {
    var baskets: [Basket] = []
    var detail: BasketDetail?
    var loading = false
    var error: String?

    func load() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        do { baskets = try await API.shared.baskets().baskets; self.error = nil }
        catch { if baskets.isEmpty { self.error = Failure.loading("baskets", error) } }
    }

    func load(_ id: String) async {
        do { detail = try await API.shared.basket(id); self.error = nil }
        catch { self.error = Failure.loading("this basket", error) }
    }
}

/// The user's open basket positions. Refetched after a submit, on pull-to-refresh and when the
/// Wallet tab opens; P&L is the backend's against what was paid, fees included.
@Observable @MainActor
final class BasketPositionsStore {
    static let shared = BasketPositionsStore()
    var positions: [BasketPosition] = []
    var loaded = false

    func load() async {
        if let r = try? await API.shared.basketPositions() { positions = r.positions; loaded = true }
    }
    func position(_ basketId: String) -> BasketPosition? { positions.first { $0.basketId == basketId } }
}

/// Opening or closing a basket: quote, sign every leg, submit, report. One Jupiter swap per
/// stock, each signed exactly like a swap. Privy's embedded wallet signs silently, so a loop
/// of N signatures is invisible to the user.
@Observable @MainActor
final class BasketOrderStore {
    enum Phase: Equatable { case idle, quoting, ready, signing(Int), submitting, retrying, done, failed }

    let basketId: String
    let name: String
    let sell: Bool
    var phase: Phase = .idle
    var quote: BasketQuote?
    var result: BasketSubmitResponse?
    var error: String?
    /// Legs that have been through Privy so far — drives "3/7 signed".
    var signed = 0
    /// Symbol for every request id this order has issued, first quote and retries alike.
    private var symbols: [String: String] = [:]
    /// What each stock ended up as across every attempt: a leg that lands on a retry replaces
    /// the failed one from the first pass, so the list reads per stock, not per try.
    var outcomes: [BasketSubmitResponse.Leg] = []
    /// Set once the automatic retry has run; the next retry is the user's to ask for.
    var retriedOnce = false

    init(basketId: String, name: String, sell: Bool) {
        self.basketId = basketId; self.name = name; self.sell = sell
    }

    var legCount: Int { outcomes.isEmpty ? (quote?.legs.count ?? 0) : outcomes.count }
    var landed: Int { outcomes.filter(\.landed).count }
    var failedLegs: [BasketSubmitResponse.Leg] { outcomes.filter { !$0.landed } }
    /// A buy that landed some stocks and not others. Sells re-quote whatever is left instead.
    var canRetry: Bool { !sell && !failedLegs.isEmpty && result != nil }

    func symbol(for requestId: String) -> String { symbols[requestId] ?? "—" }

    private func remember(_ q: BasketQuote) {
        for l in q.legs { if let s = l.symbol { symbols[l.requestId] = s } }
    }

    private func merge(_ r: BasketSubmitResponse) {
        for leg in r.legs {
            let sym = symbol(for: leg.requestId)
            if let i = outcomes.firstIndex(where: { symbol(for: $0.requestId) == sym }) {
                if !outcomes[i].landed { outcomes[i] = leg }
            } else {
                outcomes.append(leg)
            }
        }
    }

    func getQuote(amountUsd: Double, taker: String) async {
        error = nil; result = nil; signed = 0; outcomes = []; retriedOnce = false
        phase = .quoting
        do {
            quote = sell ? try await API.shared.basketSell(basketId, taker: taker)
                         : try await API.shared.basketQuote(basketId, amountUsd: amountUsd, taker: taker)
            quote.map(remember)
            phase = .ready
        } catch {
            self.error = Self.message(error); phase = .failed
        }
    }

    /// Signs every leg, then submits them together. A 410 means a leg expired between quote and
    /// submit — the whole basket is re-quoted and the user confirms the new numbers, because the
    /// legs were priced as a set.
    func send(wallet: any EmbeddedSolanaWallet, amountUsd: Double, taker: String) async {
        guard let q = quote else { return }
        error = nil
        do {
            let r = try await signAndSubmit(q, wallet: wallet)
            // Seven swaps cannot share one transaction, so a basket can land in part. One quiet
            // retry of just the stocks that missed covers the usual cause (a quote that went
            // stale while the others were landing). After that the user decides.
            if r.status == "partial", !sell {
                retriedOnce = true
                await retry(wallet: wallet)
            } else {
                finish(r.status)
            }
        } catch APIError.http(410, _) {
            await getQuote(amountUsd: amountUsd, taker: taker)
            if phase == .ready { error = "Prices refreshed — check the numbers and confirm again." }
        } catch {
            self.error = Self.message(error); phase = .failed
        }
    }

    /// Fresh quotes for the stocks that have not landed, signed and submitted under the same order.
    func retry(wallet: any EmbeddedSolanaWallet) async {
        error = nil
        phase = .retrying
        do {
            let q = try await API.shared.basketRetry(orderId: quote?.orderId ?? "")
            remember(q)
            let r = try await signAndSubmit(q, wallet: wallet)
            finish(r.status)
        } catch APIError.http(409, let raw) where raw.contains("nothing_to_retry") {
            // Everything is in after all; the position list is the truth.
            finish("done")
        } catch {
            self.error = Self.message(error)
            phase = result == nil ? .failed : .done
        }
    }

    private func signAndSubmit(_ q: BasketQuote, wallet: any EmbeddedSolanaWallet) async throws -> BasketSubmitResponse {
        var out: [(requestId: String, signedTransaction: String)] = []
        signed = 0
        for (i, leg) in q.legs.enumerated() {
            phase = .signing(i + 1)
            let s = try await SolanaTx.sign(leg.transaction, with: wallet)
            out.append((leg.requestId, s)); signed = i + 1
        }
        phase = .submitting
        let r = try await API.shared.basketSubmit(orderId: q.orderId, signed: out)
        result = r
        merge(r)
        return r
    }

    private func finish(_ status: String) {
        phase = status == "failed" ? .failed : .done
        if status == "failed" { error = "None of the swaps went through. Nothing was charged." }
        Task { await BasketPositionsStore.shared.load() }
    }

    static func message(_ error: Error) -> String {
        if case APIError.http(let code, let raw) = error {
            let reason = raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
            let r = reason.lowercased()
            if r.contains("below_minimum") { return "Minimum is $10." }
            if r.contains("nothing_to_sell") { return "Nothing left to sell in this basket." }
            if r.contains("nothing_to_retry") { return "Everything in this basket has already landed." }
            if r.contains("retry_buy_only") { return "To finish a sell, tap Close position again." }
            if r.contains("insufficient") { return "Not enough USDC." }
            if r.contains("no_route") {
                let sym = reason.split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) }
                return "Couldn't price \(sym ?? "one stock") right now. Try again."
            }
            if code == 404 { return "That basket isn't available any more." }
            if code == 429 { return "Slow down — try again in a bit." }
            if code == 410 { return "Prices expired. Getting fresh ones." }
        }
        return Failure.action(error)
    }
}
