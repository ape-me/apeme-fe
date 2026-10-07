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
    enum Phase: Equatable { case idle, quoting, ready, signing(Int), submitting, done, failed }

    let basketId: String
    let name: String
    let sell: Bool
    var phase: Phase = .idle
    var quote: BasketQuote?
    var result: BasketSubmitResponse?
    var error: String?
    /// Legs that have been through Privy so far — drives "3/7 signed".
    var signed = 0

    init(basketId: String, name: String, sell: Bool) {
        self.basketId = basketId; self.name = name; self.sell = sell
    }

    var legCount: Int { quote?.legs.count ?? 0 }
    var landed: Int { result?.legs.filter(\.landed).count ?? 0 }
    var failedLegs: [BasketSubmitResponse.Leg] { result?.legs.filter { !$0.landed } ?? [] }

    func symbol(for requestId: String) -> String {
        quote?.legs.first { $0.requestId == requestId }?.symbol ?? "—"
    }

    func getQuote(amountUsd: Double, taker: String) async {
        error = nil; result = nil; signed = 0
        phase = .quoting
        do {
            quote = sell ? try await API.shared.basketSell(basketId, taker: taker)
                         : try await API.shared.basketQuote(basketId, amountUsd: amountUsd, taker: taker)
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
            var out: [(requestId: String, signedTransaction: String)] = []
            for (i, leg) in q.legs.enumerated() {
                phase = .signing(i + 1)
                let s = try await SolanaTx.sign(leg.transaction, with: wallet)
                out.append((leg.requestId, s)); signed = i + 1
            }
            phase = .submitting
            let r = try await API.shared.basketSubmit(orderId: q.orderId, signed: out)
            result = r
            phase = r.status == "failed" ? .failed : .done
            if r.status == "failed" { error = "None of the swaps went through. Nothing was charged." }
            await BasketPositionsStore.shared.load()
        } catch APIError.http(410, _) {
            await getQuote(amountUsd: amountUsd, taker: taker)
            if phase == .ready { error = "Prices refreshed — check the numbers and confirm again." }
        } catch {
            self.error = Self.message(error); phase = .failed
        }
    }

    static func message(_ error: Error) -> String {
        if case APIError.http(let code, let raw) = error {
            let reason = raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
            let r = reason.lowercased()
            if r.contains("below_minimum") { return "Minimum is $10." }
            if r.contains("nothing_to_sell") { return "Nothing left to sell in this basket." }
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
