import SwiftUI

/// Everything about one order: what you set, what it has taken so far, what it is holding of
/// yours, and what it cost. Opened by tapping a row anywhere orders are listed.
struct OrderDetailSheet: View {
    let order: LimitOrder
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var store = OrdersStore.shared

    /// The live copy if the list has refreshed under us, so a fill lands while this is open.
    private var o: LimitOrder { store.orders.first { $0.id == order.id } ?? order }
    private var stock: Stock? { app.stocksByMint[o.mint] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                headline
                if o.isPartial { progress }
                detail
                if let e = o.error, !e.isEmpty {
                    Text(e).font(.sub).foregroundStyle(Theme.red).lineSpacing(2)
                        .padding(.horizontal, 20).padding(.top, 16)
                }
                if o.isOpen { cancel }
                if let sig = o.signature, let url = URL(string: "https://solscan.io/tx/\(sig)") {
                    Button { openURL(url) } label: {
                        HStack(spacing: 6) {
                            Text("View on Solscan").font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)
                }
            }
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Theme.surface)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Logo(url: stock?.logoURL, symbol: o.symbol, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(o.symbol).font(.system(size: 17, weight: .semibold))
                Text(statusLine).font(.sub).foregroundStyle(Theme.muted)
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close") { dismiss() }
        }
        .padding(.horizontal, 20).padding(.top, 14)
    }

    private var statusLine: String {
        if o.isPartial { return "Part filled · still open" }
        if o.isExpired { return "Expired · your money is still held" }
        switch o.status {
        case "open": return "Waiting for your price"
        case "filled": return o.filledAt.map { "Filled \(Fmt.ago($0)) ago" } ?? "Filled"
        case "cancelled": return "Cancelled"
        case "failed": return "Didn't go through"
        default: return o.status.capitalized
        }
    }

    /// The one sentence the order is: side, size, trigger.
    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(o.isBuy ? "Buy" : "Sell") \(Fmt.cash(o.makingUsd))")
                .font(.system(size: 28, weight: .bold)).tracking(-0.8).monospacedDigit()
            Text("when \(o.symbol) hits \(Fmt.usd(o.triggerUsd))")
                .font(.system(size: 15)).foregroundStyle(Theme.muted)
            if let away = o.awayPct(from: stock?.priceUsd), o.isOpen {
                Text("\(Fmt.usd(stock?.priceUsd)) now · \(away >= 0 ? "+" : "−")\(String(format: "%.1f", abs(away)))% away")
                    .font(.sub).monospacedDigit().foregroundStyle(Theme.faint)
            }
        }
        .padding(.horizontal, 20).padding(.top, 22)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(Fmt.cash(o.filledUsdValue)) of \(Fmt.cash(o.makingUsd)) filled")
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                Spacer()
                Text("\(Int(((o.filledFraction ?? 0) * 100).rounded()))%")
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.amber)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.amber).frame(width: g.size.width * min(1, max(0.02, o.filledFraction ?? 0)))
                }
            }
            .frame(height: 6)
            Text("The rest is still working at your price.")
                .font(.sub).foregroundStyle(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface2, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 20).padding(.top, 20)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Order").padding(.horizontal, 4)
            KCard {
                KV("Type", o.isBuy ? "Limit buy" : "Limit sell")
                KV("Your price", Fmt.usd(o.triggerUsd))
                KV(o.isBuy ? "Amount" : "Worth today", Fmt.cash(o.makingUsd))
                if let f = o.filledUsdValue, (o.filledFraction ?? 0) > 0.001 {
                    KV("Filled", Fmt.cash(f))
                }
                if o.isBuy, o.isOpen, let e = o.escrowUsd {
                    KV("Reserved") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.cash(e))
                            Text("not spendable").font(.system(size: 11)).foregroundStyle(Theme.faint)
                        }
                    }
                }
                if let fee = o.feeUsd, fee > 0 { KV("Fee", Fmt.cash(fee)) }
                if let rent = o.rentUsd, rent > 0 {
                    KV("Solana deposit") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.cash(rent))
                            Text("comes back when it closes").font(.system(size: 11)).foregroundStyle(Theme.faint)
                        }
                    }
                }
            }
            SectionTitle("Timing").padding(.horizontal, 4).padding(.top, 22)
            KCard {
                if let c = o.createdAt { KV("Placed", Fmt.dateTime(c)) }
                if let f = o.filledAt { KV("Filled", Fmt.dateTime(f)) }
                if let e = o.expiresAt {
                    KV(o.isExpired ? "Expired" : "Expires") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.dateTime(e))
                            if o.isOpen, !o.isExpired {
                                let days = Int((Double(e) - Date.now.timeIntervalSince1970) / 86_400)
                                Text("in \(max(0, days))d").font(.system(size: 11)).foregroundStyle(Theme.faint)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 24)
    }

    private var cancel: some View {
        VStack(spacing: 10) {
            BigButton(label: store.cancelling == o.id ? (o.needsReclaim ? "Releasing…" : "Cancelling…")
                                                      : (o.needsReclaim ? "Reclaim funds" : "Cancel order"),
                      style: o.needsReclaim ? .buy : .ghost) {
                guard let w = app.auth.activeWallet else { app.show("Sign in first.", error: true); return }
                Haptic.medium()
                Task {
                    do {
                        try await store.cancel(o.id, wallet: w)
                        app.show(o.needsReclaim ? "Funds released back to your balance" : "Order cancelled · funds returned")
                        dismiss()
                    } catch { app.show(OrdersStore.message(error), error: true) }
                }
            }
            .disabled(store.cancelling != nil)
            Text(o.needsReclaim
                 ? (o.isBuy ? "This order passed its deadline without filling. The cash is still reserved on chain until you release it."
                            : "This order passed its deadline without filling. Releasing it closes the order out.")
                 : (o.isBuy ? "The reserved cash goes back to your balance." : "Your position stays where it is."))
                .font(.sub).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20).padding(.top, 24)
    }
}
