import SwiftUI

/// Open and past orders, either for one stock or for everything. The wallet and a stock page
/// render an order identically because they render it from here.
struct OrdersPanel: View {
    /// nil means every stock.
    var mint: String? = nil
    @Environment(AppState.self) private var app
    @State private var store = OrdersStore.shared
    @State private var showPast = false
    @State private var detail: LimitOrder?

    private var open: [LimitOrder] {
        let all = mint.map(store.open(for:)) ?? store.open
        // Expired orders are still holding money and need a tap, so they lead.
        return all.filter(\.needsReclaim) + all.filter { !$0.needsReclaim }
    }
    private var expired: [LimitOrder] { open.filter(\.needsReclaim) }
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
                // The money is still theirs and only a tap gets it back, so say so before the list.
                if !expired.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 14)).foregroundStyle(Theme.amber)
                        Text(expired.count == 1
                             ? "One order expired without filling. Your money is still held — tap Reclaim to get it back."
                             : "\(expired.count) orders expired without filling. Your money is still held — tap Reclaim to get it back.")
                            .font(.sub).foregroundStyle(Theme.ink).lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.amberT, in: .rect(cornerRadius: 12))
                    .padding(.bottom, 12)
                }
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
        .sheet(item: $detail) { OrderDetailSheet(order: $0) }
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
        Button { Haptic.selection(); detail = o } label: { rowBody(o) }
            .buttonStyle(.plain)
    }

    private func rowBody(_ o: LimitOrder) -> some View {
        let stock = app.stocksByMint[o.mint]
        let away = o.awayPct(from: stock?.priceUsd)
        return HStack(spacing: 12) {
            Logo(url: stock?.logoURL, symbol: o.symbol, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(o.symbol).font(.system(size: 15, weight: .semibold))
                    badge(o)
                }
                Text(subtitle(o, away: away))
                    .font(.sub).monospacedDigit().foregroundStyle(Theme.muted).lineLimit(1)
                // A part-filled order is still working: show how far it got, not one end state.
                if let f = o.filledFraction, o.isPartial {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(Theme.amber).frame(width: g.size.width * min(1, max(0.02, f)))
                        }
                    }
                    .frame(height: 3).padding(.top, 2)
                }
            }
            Spacer(minLength: 8)
            if o.isOpen { cancelButton(o) }
            else { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint) }
        }
        .frame(minHeight: 64)
        .contentShape(.rect)
    }

    @ViewBuilder private func badge(_ o: LimitOrder) -> some View {
        if o.isPartial {
            chip("PART FILLED", Theme.amber, Theme.amberT)
        } else if o.isExpired {
            chip("EXPIRED", Theme.muted, Theme.greyT)
        } else if o.isOpen {
            chip(o.side.uppercased(), o.isBuy ? Theme.green : Theme.red, o.isBuy ? Theme.greenT : Theme.redT)
        } else {
            Text(o.status).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.faint)
        }
    }

    private func chip(_ text: String, _ fg: Color, _ bg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold)).tracking(0.4)
            .foregroundStyle(fg)
            .padding(.horizontal, 6).frame(height: 17)
            .background(bg, in: .rect(cornerRadius: 5))
    }

    private func subtitle(_ o: LimitOrder, away: Double?) -> String {
        let head = "\(Fmt.cash(o.makingUsd)) at \(Fmt.usd(o.triggerUsd))"
        // Partly filled, open or closed: the fraction is the story.
        if let part = o.filledUsdValue, let f = o.filledFraction, f > 0.001, f < 0.999 {
            let tail = o.isOpen ? "still open" : o.status
            return "\(Fmt.cash(part)) of \(Fmt.cash(o.makingUsd)) filled · \(tail)"
        }
        // Past its deadline. We do not know yet whether Jupiter returns the escrow on its own,
        // so this says what to do and promises nothing.
        if o.isExpired { return head + " · funds still held" }
        if o.isOpen, let away {
            let gap = " · \(away >= 0 ? "+" : "−")\(String(format: "%.1f", abs(away)))% away"
            // Only once the clock is worth watching — an order with three weeks left says nothing.
            if let exp = o.expiresAt {
                let days = Int((Double(exp) - Date.now.timeIntervalSince1970) / 86_400)
                if days <= 7 { return head + gap + " · \(max(0, days))d left" }
            }
            return head + gap
        }
        if let ts = o.filledAt ?? o.createdAt { return head + " · \(Fmt.ago(ts)) ago" }
        return head
    }

    private func cancelButton(_ o: LimitOrder) -> some View {
        Button {
            guard let w = app.auth.activeWallet else { app.show("Sign in first.", error: true); return }
            Haptic.medium()
            Task {
                do {
                    try await store.cancel(o.id, wallet: w)
                    app.show(o.needsReclaim ? "Funds released back to your balance" : "Order cancelled · funds returned")
                }
                catch { app.show(OrdersStore.message(error), error: true) }
            }
        } label: {
            Group {
                if store.cancelling == o.id { ProgressView().tint(Theme.ink).scaleEffect(0.7) }
                else {
                    Text(o.needsReclaim ? "Reclaim" : "Cancel")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(o.needsReclaim ? Theme.ground : Theme.ink)
                }
            }
            .padding(.horizontal, 12).frame(height: 32)
            .background(o.needsReclaim ? Theme.amber : Theme.surface2, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(store.cancelling != nil)
    }
}
