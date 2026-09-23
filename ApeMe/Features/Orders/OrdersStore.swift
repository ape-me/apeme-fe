import SwiftUI
import Observation
import PrivySDK

/// One store for every surface that shows orders — the wallet's tab and each stock's own — so a
/// cancel on either is reflected on both without either having to know about the other.
/// `GET /v1/orders` reconciles against Jupiter on every read, so refetching on appear is enough.
@Observable @MainActor
final class OrdersStore {
    static let shared = OrdersStore()

    var orders: [LimitOrder] = []
    var loading = false
    var loaded = false
    var error: String?
    /// The order currently being cancelled, so its row can show the work.
    var cancelling: String?
    /// Read from the BE at launch. Nothing about order limits is hardcoded: the minimum moves
    /// from their admin panel, the account cost tracks the SOL price, and the excluded issuers
    /// decide which stocks offer limit orders at all.
    var config: OrderConfig = .provisional
    var minUsd: Double? { config.minUsd }

    func loadConfig() async {
        if let c = try? await API.shared.orderConfig() { config = c }
    }

    /// A refusal states the rule it enforced, so the UI adopts it immediately rather than
    /// waiting for the next config read.
    func adopt(_ error: Error) {
        guard case APIError.orderRefused(_, let min, let excluded) = error else { return }
        config = OrderConfig(minUsd: min ?? config.minUsd, maxOpen: config.maxOpen,
                             buyFeeBps: config.buyFeeBps, sellFeeBps: config.sellFeeBps,
                             accountCostUsd: config.accountCostUsd, minGapBps: config.minGapBps,
                             ttlDays: config.ttlDays, excludedIssuers: excluded ?? config.excludedIssuers)
    }

    /// Order failures are rare and specific, so the BE's own words beat a guess. A swap's generic
    /// "trade didn't go through" hides exactly the reason the user needs.
    static func message(_ error: Error) -> String {
        if case APIError.insufficientFunds(let short) = error {
            return short > 0 ? "Add \(Fmt.cash(short)) USDC to place this order" : "Not enough USDC for this order."
        }
        if case APIError.orderRefused(let reason, _, _) = error {
            return reason.prefix(1).uppercased() + reason.dropFirst() + "."
        }
        if case APIError.http(let code, let raw) = error {
            // Drop the request id the API appends for debugging, keep the reason.
            let reason = raw.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? raw
            if code == 429 { return "Too many orders this hour. Take a breath." }
            if reason.lowercased().contains("invite_required") { return "Enter your invite code first." }
            if reason == "request failed" { return "The order was refused and we weren't told why." }
            // snake_case from the BE reads as a sentence: minimum_order_size -> Minimum order size.
            let words = reason.replacingOccurrences(of: "_", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst() + "."
        }
        if error is DecodingError { return "Couldn't read the order. Try again." }
        return "No connection. Try again."
    }



    private var socket: LiveSocket?
    private var listener: Task<Void, Never>?
    /// What just happened, for the surface that can show a toast.
    var lastEvent: WsOrder?

    private init() {}

    /// The channel is the authorisation, so it is passed in rather than read from anywhere global.
    func connect(channel: String, onEvent: @escaping (WsOrder) -> Void) {
        guard socket == nil else { return }
        let s = LiveSocket(room: channel)
        socket = s
        listener = Task { [weak self] in
            for await ev in s.events {
                guard let self, case .frames(let frames) = ev else { continue }
                for case .order(let o) in frames {
                    lastEvent = o
                    onEvent(o)
                    await load()
                }
            }
        }
        s.start()
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        socket?.stop(); socket = nil
    }

    var open: [LimitOrder] { orders.filter(\.isOpen) }
    var past: [LimitOrder] { orders.filter { !$0.isOpen } }

    func open(for mint: String) -> [LimitOrder] { open.filter { $0.mint == mint } }
    func all(for mint: String) -> [LimitOrder] { orders.filter { $0.mint == mint } }

    /// Money locked in open buys. Reserved, never spendable.
    var reservedUsd: Double { open.filter(\.isBuy).reduce(0) { $0 + ($1.escrowUsd ?? 0) } }

    func load() async {
        if config.minUsd == nil { await loadConfig() }
        guard !loading else { return }
        loading = true
        defer { loading = false; loaded = true }
        do {
            orders = try await API.shared.orders(limit: 50).orders
            error = nil
        } catch {
            if orders.isEmpty { self.error = "Couldn't load your orders." }
        }
    }

    /// Place: quote, sign, submit. Nothing is charged unless it fills.
    func place(wallet: any EmbeddedSolanaWallet, address: String, mint: String, side: String,
               amountRaw: String, triggerUsd: Double) async throws {
        let q = try await API.shared.orderQuote(wallet: address, mint: mint, side: side,
                                                amountRaw: amountRaw, triggerUsd: triggerUsd)
        let signed = try await SolanaTx.sign(q.transaction, with: wallet)
        _ = try await API.shared.submitOrder(id: q.id, signedTransaction: signed)
        await load()
    }

    /// Cancel is a second signature — the escrow comes back in full.
    func cancel(_ id: String, wallet: any EmbeddedSolanaWallet) async throws {
        cancelling = id
        defer { cancelling = nil }
        let tx = try await API.shared.cancelOrder(id: id).transaction
        let signed = try await SolanaTx.sign(tx, with: wallet)
        _ = try await API.shared.submitCancel(id: id, signedTransaction: signed)
        await load()
    }
}
