import Foundation
import Observation
import PrivySDK

/// The list and one detail at a time. Both are public, cached 60s on the backend.
@Observable @MainActor
final class BasketsStore {
    /// One list for the Home grid and the See more page, loaded alongside the rest of Home so
    /// the tiles are there when the page is, not a second later.
    static let shared = BasketsStore()
    var baskets: [Basket] = []
    /// Four ideas for the builder, shown as chips on Explore.
    var ideas: [String] = []
    var detail: BasketDetail?
    var loading = false
    var error: String?

    func load() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        async let i = API.shared.basketIdeas()
        do { baskets = try await API.shared.baskets().baskets; self.error = nil }
        catch { if baskets.isEmpty { self.error = Failure.loading("baskets", error) } }
        if let r = try? await i { ideas = r.ideas }
    }

    /// A basket the AI just built, kept so its page opens on it rather than fetching it again.
    nonisolated(unsafe) private static var fresh: [String: BasketDetail] = [:]
    func remember(_ d: BasketDetail) { Self.fresh[d.id] = d }

    func load(_ id: String) async {
        if let d = Self.fresh.removeValue(forKey: id) { detail = d; error = nil; return }
        do { detail = try await API.shared.basket(id); self.error = nil }
        catch APIError.http(404, _) where id.hasPrefix("ai_") {
            self.error = "This draft has expired. Build it again from your idea."
        }
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
    /// The user's own mix, if they changed it; nil buys the basket as built.
    var weights: [String: Int]?
    /// The basket's own mix and its symbol → ticker map, so a stock that will not quote can be
    /// dropped from here without going back to the page.
    var baseWeights: [String: Int] = [:]
    var tickers: [String: String] = [:]
    /// The stock the last quote failed on, when the backend named one.
    var failedSymbol: String?

    /// Drop one stock from the mix and ask again.
    func dropAndRequote(_ symbol: String, amountUsd: Double, taker: String) async {
        guard let key = tickers[symbol] else { return }
        var w = weights ?? baseWeights
        w[key] = 0
        guard w.values.contains(where: { $0 > 0 }) else { return }
        weights = w
        await getQuote(amountUsd: amountUsd, taker: taker)
    }
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
    /// The legs that failed did so for want of USDC; buying them again would fail the same way.
    var ranOutOfMoney: Bool { failedLegs.contains { ($0.error ?? "").lowercased().contains("insufficient") } }

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
        error = nil; result = nil; signed = 0; outcomes = []; retriedOnce = false; failedSymbol = nil
        phase = .quoting
        do {
            quote = try await fetchQuote(amountUsd: amountUsd, taker: taker)
            quote.map(remember)
            phase = .ready
        } catch {
            if case APIError.pricing(_, let sym, _) = error { failedSymbol = sym }
            self.error = Self.message(error); phase = .failed
        }
    }

    /// Seven legs means seven Jupiter quotes at once, and one of them failing on Jupiter's side
    /// is a bad second, not a bad basket. A quiet second attempt covers it before anyone is told.
    private func fetchQuote(amountUsd: Double, taker: String) async throws -> BasketQuote {
        // Three quiet goes with a growing pause: a rate limit or a flaky route on one of seven
        // legs clears in seconds, and nobody should see it.
        var last: Error?
        for (i, pause) in [0.0, 1.2, 2.5, 4.0].enumerated() {
            if pause > 0 { try? await Task.sleep(for: .seconds(pause)) }
            do {
                return sell ? try await API.shared.basketSell(basketId, taker: taker)
                            : try await API.shared.basketQuote(basketId, amountUsd: amountUsd, taker: taker, weights: weights)
            } catch let e where Self.isUpstreamHiccup(e) && i < 3 {
                last = e
            }
        }
        throw last ?? APIError.http(502, "upstream_error")
    }

    /// Jupiter failing to answer, or the backend saying it could not route: worth one more go.
    private static func isUpstreamHiccup(_ error: Error) -> Bool {
        if case APIError.pricing = error { return true }
        guard case APIError.http(let code, _) = error else { return false }
        // ondo_unavailable is already retried on the backend; a second go here only delays the message.
        if case APIError.pricing(let reason, _, _) = error, reason == "ondo_unavailable" { return false }
        return code >= 500
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
            if r.status == "partial", !sell, !ranOutOfMoney {
                retriedOnce = true
                await retry(wallet: wallet)
            } else {
                if ranOutOfMoney { error = "Ran out of USDC part way. Add funds to buy the rest." }
                finish(r.status)
            }
        } catch APIError.http(410, _) {
            await getQuote(amountUsd: amountUsd, taker: taker)
            if phase == .ready { error = "Prices refreshed — check the numbers and confirm again."; Haptic.warning() }
        } catch {
            self.error = Self.message(error); phase = .failed
            Haptic.error()
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
            Haptic.error()
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

    /// The phone says how it went before the eye has read it: a success tap when every stock
    /// landed, a warning when some did, an error when none did.
    private func finish(_ status: String) {
        phase = status == "failed" ? .failed : .done
        if status == "failed" {
            error = "None of the swaps went through. Nothing was charged."
            Haptic.error()
        } else if failedLegs.isEmpty {
            Haptic.success()
        } else {
            Haptic.warning()
        }
        Task { await BasketPositionsStore.shared.load() }
    }

    static func message(_ error: Error) -> String {
        // A mix whose smallest slice would be under a dollar: the backend names the floor.
        if case APIError.orderRefused(_, let min, _) = error, let min { return "Minimum \(Fmt.cash(min)) for this basket." }
        if case APIError.http(let code, let raw) = error {
            let reason = raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
            let r = reason.lowercased()
            if r.contains("below_minimum") { return "Minimum is $10." }
            if r.contains("nothing_to_sell") { return "Nothing left to sell in this basket." }
            if r.contains("nothing_to_retry") { return "Everything in this basket has already landed." }
            if r.contains("retry_buy_only") { return "To finish a sell, tap Close position again." }
            if r.contains("insufficient") { return "Not enough USDC." }

            if code == 404 { return "That basket isn't available any more." }
            if code == 429 { return "Slow down — try again in a bit." }
            if code == 410 { return "Prices expired. Getting fresh ones." }
        }
        return Failure.action(error)
    }
}
