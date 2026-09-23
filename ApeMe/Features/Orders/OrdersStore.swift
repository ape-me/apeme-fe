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

    private init() {}

    var open: [LimitOrder] { orders.filter(\.isOpen) }
    var past: [LimitOrder] { orders.filter { !$0.isOpen } }

    func open(for mint: String) -> [LimitOrder] { open.filter { $0.mint == mint } }
    func all(for mint: String) -> [LimitOrder] { orders.filter { $0.mint == mint } }

    /// Money locked in open buys. Reserved, never spendable.
    var reservedUsd: Double { open.filter(\.isBuy).reduce(0) { $0 + ($1.escrowUsd ?? 0) } }

    func load() async {
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
