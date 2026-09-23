import SwiftUI

/// Open and past orders, either for one stock or for everything. The wallet and a stock page
/// render an order identically because they render it from here.
struct OrdersPanel: View {
    /// nil means every stock.
    var mint: String? = nil
    @Environment(AppState.self) private var app
    @State private var store = OrdersStore.shared
    @State private var showPast = false

    private var open: [LimitOrder] { mint.map(store.open(for:)) ?? store.open }
    private var past: [LimitOrder] { (mint.map(store.all(for:)) ?? store.orders).filter { !$0.isOpen } }
    private var reserved: Double { open.filter(\.isBuy).reduce(0) { $0 + ($1.escrowUsd ?? 0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pills
            if let err = store.error, store.orders.isEmpty {
                ErrorBar(text: err)
            } else if !store.loaded, store.loading {
                VStack(spacing: 12) { ForEach(0..<2, id: \.self) { _ in Skeleton(height: 64) } }
            } else if showPast {
                if past.isEmpty {
                    EmptyState(title: "Nothing here yet.", subtitle: "Filled and cancelled orders show up here.")
                } else {
                    KCard { ForEach(past) { row($0) } }
                }
            } else if open.isEmpty {
                EmptyState(title: "No waiting orders.", subtitle: "Set a price with Limit and it fills while you sleep.")
            } else {
                KCard { ForEach(open) { row($0) } }
                if reserved > 0 {
                    Text("\(Fmt.cash(reserved)) reserved — not spendable until they fill or you cancel.")
                        .font(.sub).foregroundStyle(Theme.muted).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }
            }
        }
        .task { if !store.loaded { await store.load() } }
    }

    private var pills: some View {
        HStack(spacing: 8) {
            pill("Open", open.count, on: !showPast) { showPast = false }
            pill("History", past.count, on: showPast) { showPast = true }
            Spacer()
        }
        .padding(.bottom, 12)
    }

    private func pill(_ label: String, _ count: Int, on: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptic.selection(); action() } label: {
            Text(count > 0 ? "\(label) · \(count)" : label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? Theme.ground : Theme.ink)
                .padding(.horizontal, 12).frame(height: 32)
                .background(on ? Theme.ink : Theme.surface2, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func row(_ o: LimitOrder) -> some View {
        let stock = app.stocksByMint[o.mint]
        let away = o.awayPct(from: stock?.priceUsd)
        return HStack(spacing: 12) {
            Logo(url: stock?.logoURL, symbol: o.symbol, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(o.symbol).font(.system(size: 15, weight: .semibold))
                    if o.isOpen {
                        Text(o.side.uppercased())
                            .font(.system(size: 9, weight: .bold)).tracking(0.4)
                            .foregroundStyle(o.isBuy ? Theme.green : Theme.red)
                            .padding(.horizontal, 6).frame(height: 17)
                            .background(o.isBuy ? Theme.greenT : Theme.redT, in: .rect(cornerRadius: 5))
                    } else {
                        Text(o.status).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.faint)
                    }
                }
                Text(subtitle(o, away: away))
                    .font(.sub).monospacedDigit().foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            if o.isOpen { cancelButton(o) }
        }
        .frame(minHeight: 64)
    }

    private func subtitle(_ o: LimitOrder, away: Double?) -> String {
        let head = "\(Fmt.cash(o.makingUsd)) at \(Fmt.usd(o.triggerUsd))"
        if o.isOpen, let away { return head + " · \(away >= 0 ? "+" : "−")\(String(format: "%.1f", abs(away)))% away" }
        if let ts = o.filledAt ?? o.createdAt { return head + " · \(Fmt.ago(ts)) ago" }
        return head
    }

    private func cancelButton(_ o: LimitOrder) -> some View {
        Button {
            guard let w = app.auth.activeWallet else { app.show("Sign in first.", error: true); return }
            Haptic.medium()
            Task {
                do { try await store.cancel(o.id, wallet: w); app.show("Order cancelled · funds returned") }
                catch { app.show(TradeStore.message(error), error: true) }
            }
        } label: {
            Group {
                if store.cancelling == o.id { ProgressView().tint(Theme.ink).scaleEffect(0.7) }
                else { Text("Cancel").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink) }
            }
            .padding(.horizontal, 12).frame(height: 32)
            .background(Theme.surface2, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(store.cancelling != nil)
    }
}
