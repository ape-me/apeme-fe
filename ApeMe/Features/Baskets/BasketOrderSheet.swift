import SwiftUI

/// Invest in, or close, a basket: review the legs, sign them all, watch them land.
struct BasketOrderSheet: View {
    let basketId: String
    let name: String
    let sell: Bool
    let amountUsd: Double
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var store: BasketOrderStore

    init(basketId: String, name: String, sell: Bool, amountUsd: Double) {
        self.basketId = basketId; self.name = name; self.sell = sell; self.amountUsd = amountUsd
        _store = State(initialValue: BasketOrderStore(basketId: basketId, name: name, sell: sell))
    }

    private var title: String {
        switch store.phase {
        case .done: sell ? "Closed" : "Bought"
        default: sell ? "Close \(name)?" : "Buy \(name)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(title).h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(busy) }
                .padding(.bottom, 18)
            content
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ground)
        .presentationDetents([.large])
        .presentationBackground(Theme.ground)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .task { if let t = app.walletAddress { await store.getQuote(amountUsd: amountUsd, taker: t) } }
    }

    private var busy: Bool {
        switch store.phase { case .quoting, .signing, .submitting: true; default: false }
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .idle, .quoting:
            VStack(alignment: .leading, spacing: 14) {
                Text(sell ? "Pricing every stock in the basket…" : "Getting prices for the stocks…")
                    .font(.sub).foregroundStyle(Theme.muted)
                Skeleton(height: 52); Skeleton(height: 52); Skeleton(height: 52)
                Spacer()
            }
        case .ready, .signing, .submitting:
            if let q = store.quote { review(q) }
        case .done:
            result
        case .failed:
            VStack(alignment: .leading, spacing: 14) {
                if let q = store.quote, store.result == nil { review(q) }
                else {
                    ErrorBar(text: store.error ?? "That didn't go through.").padding(.horizontal, -20)
                    Spacer()
                    BigButton(label: "Try again", style: .white) {
                        Task { if let t = app.walletAddress { await store.getQuote(amountUsd: amountUsd, taker: t) } }
                    }
                }
            }
        }
    }

    private func review(_ q: BasketQuote) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sell ? "≈ \(Fmt.cash(q.totalOutUsd)) USDC" : Fmt.cash(q.amountUsd))
                    .font(.system(size: 30, weight: .semibold)).tracking(-0.8).monospacedDigit()
                Text(sell ? "for everything in \(name)" : "across \(q.legs.count) stocks, equal weight")
                    .font(.sub).foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(q.legs) { leg in
                        HStack {
                            Text(leg.symbol ?? "—").font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text(sell ? Fmt.cash(leg.outUsd) : Fmt.cash(leg.inUsd)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                        }
                        .frame(height: 44)
                        Divider().overlay(Theme.line)
                    }
                    HStack {
                        Text("Stonks247 fee 1%").font(.system(size: 15)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(Fmt.cash(q.feeUsd)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    }
                    .frame(height: 44)
                }
            }
            .scrollIndicators(.hidden)

            if let e = store.error { ErrorBar(text: e).padding(.horizontal, -20).padding(.top, 8) }

            Group {
                switch store.phase {
                case .signing(let n):
                    progress("Signing \(n)/\(store.legCount)…")
                case .submitting:
                    progress(sell ? "Selling…" : "Buying…")
                default:
                    BigButton(label: sell ? "Close basket" : "Buy \(Fmt.cash(q.amountUsd))", style: sell ? .sell : .buy) {
                        guard let w = app.auth.activeWallet, let t = app.walletAddress else { app.show("Sign in first.", error: true); return }
                        Haptic.medium()
                        Task { await store.send(wallet: w, amountUsd: amountUsd, taker: t) }
                    }
                }
            }
            .padding(.top, 14)
        }
    }

    private func progress(_ label: String) -> some View {
        HStack(spacing: 10) { ProgressView().tint(.white); Text(label).font(.system(size: 17, weight: .semibold)) }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
            .background(sell ? AnyShapeStyle(Theme.sellGradient) : AnyShapeStyle(Theme.buyGradient), in: .capsule)
    }

    /// Every leg named, landed ones ticked, failed ones red with the reason. A failed leg's USDC
    /// never left the wallet, and the sheet says so.
    private var result: some View {
        VStack(alignment: .leading, spacing: 0) {
            let r = store.result
            Text("\(store.landed)/\(store.legCount) \(sell ? "sold" : "bought")")
                .font(.system(size: 30, weight: .semibold)).tracking(-0.8).monospacedDigit()
                .foregroundStyle(store.failedLegs.isEmpty ? Theme.green : Theme.amber)
                .padding(.bottom, 16)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(r?.legs ?? []) { leg in
                        HStack(spacing: 10) {
                            Image(systemName: leg.landed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(leg.landed ? Theme.green : Theme.red)
                            Text(store.symbol(for: leg.requestId)).font(.system(size: 15, weight: .semibold))
                            Spacer()
                            if !leg.landed, let e = leg.error {
                                Text(e).font(.sub).foregroundStyle(Theme.red).lineLimit(1)
                            }
                        }
                        .frame(height: 44)
                        Divider().overlay(Theme.line)
                    }
                }
            }
            .scrollIndicators(.hidden)
            if !store.failedLegs.isEmpty {
                Text("The USDC for anything that failed is still in your wallet.")
                    .font(.sub).foregroundStyle(Theme.muted).padding(.top, 10)
            }
            BigButton(label: "Done", style: .white) { app.settleWallet(); dismiss() }.padding(.top, 14)
        }
    }
}

// MARK: - Position

struct BasketPositionRow: View {
    let position: BasketPosition
    @Environment(AppState.self) private var app

    var body: some View {
        Button { app.push(.basketPosition(position.basketId)) } label: {
            HStack(spacing: 12) {
                LogoStack(urls: position.stocks.compactMap(\.logoURL), size: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(position.name).font(.rowTitle)
                    Text("\(position.stocks.count) stocks · basket").font(.sub).foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.usd(position.valueUsd)).font(.rowPrice).monospacedDigit()
                    if let p = position.pnlUsd {
                        Text("\(Fmt.signedCash(p)) · \(Fmt.pct(position.pnlPct, 1))").font(.rowChange).monospacedDigit().foregroundStyle(Theme.change(p))
                    }
                }
            }
            .padding(.vertical, 8).frame(minHeight: 60).contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }
}

struct BasketPositionView: View {
    let basketId: String
    @Environment(AppState.self) private var app
    private var positions: BasketPositionsStore { BasketPositionsStore.shared }
    private var p: BasketPosition? { positions.position(basketId) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BackButton(); Text(p?.name ?? "Basket").h2Text(); Spacer() }
                .padding(.horizontal, 12).padding(.top, 6).frame(height: 56)
            ScrollView {
                if let p {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Fmt.usd(p.valueUsd)).font(.system(size: 34, weight: .semibold)).tracking(-1).monospacedDigit()
                            if let g = p.pnlUsd {
                                Text("\(Fmt.signedCash(g)) · \(Fmt.pct(p.pnlPct, 2))").font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.change(g))
                            }
                        }
                        KCard {
                            KV("Paid", Fmt.cash(p.paidUsd))
                            if let t = p.openedAt { KV("Opened", Fmt.date(t)) }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            SectionTitle("Holdings")
                            KCard {
                                ForEach(p.stocks.filter { ($0.valueUsd ?? 0) >= 0.01 }) { h in
                                    HStack(spacing: 12) {
                                        Logo(url: h.logoURL, symbol: h.symbol, size: 32)
                                        Text(h.symbol).font(.system(size: 15, weight: .semibold))
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(Fmt.usd(h.valueUsd)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                                            Text(Fmt.qty(h.amount ?? 0, symbol: h.symbol)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                                        }
                                    }
                                    .frame(height: 52)
                                }
                            }
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rebalance").font(.system(size: 15, weight: .semibold))
                                Text("Off").font(.sub).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text("COMING SOON").font(.system(size: 9, weight: .bold)).tracking(0.4).foregroundStyle(Theme.amber)
                                .padding(.horizontal, 6).frame(height: 17).background(Theme.amberT, in: .rect(cornerRadius: 5))
                            Toggle("", isOn: .constant(p.rebalance ?? false)).labelsHidden().disabled(true)
                        }
                        .padding(14).background(Theme.surface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
                        BigButton(label: "Close position", style: .sell) { Haptic.medium(); app.sheet = .closeBasket(p) }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                } else {
                    EmptyState(title: "This basket is closed.", subtitle: "Its stocks were sold back to USDC.")
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .task { await positions.load() }
    }
}
