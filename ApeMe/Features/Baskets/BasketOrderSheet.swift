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

    /// Quote legs carry a symbol, not a mint; the stock list already loaded gives the mark.
    private func stock(_ symbol: String?) -> Stock? {
        guard let symbol else { return nil }
        return app.stocksByMint.values.first { $0.symbol == symbol }
    }
    private var legLogos: [URL] { (store.quote?.legs ?? []).compactMap { stock($0.symbol)?.logoURL } }

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
        switch store.phase { case .quoting, .signing, .submitting, .retrying: true; default: false }
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
        case .ready, .signing, .submitting, .retrying:
            if store.result != nil { result } else if let q = store.quote { review(q) }
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
            HStack(spacing: 12) {
                LogoStack(urls: legLogos, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sell ? "≈ \(Fmt.cash(q.totalOutUsd))" : Fmt.cash(q.amountUsd))
                        .font(.system(size: 28, weight: .semibold)).tracking(-0.8).monospacedDigit()
                    Text(sell ? "USDC back for everything in \(name)" : "\(q.legs.count) stocks · equal weight")
                        .font(.sub).foregroundStyle(Theme.muted)
                }
            }
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    KCard {
                        ForEach(q.legs) { leg in
                            HStack(spacing: 12) {
                                Logo(url: stock(leg.symbol)?.logoURL, symbol: leg.symbol ?? "", size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(leg.symbol ?? "—").font(.system(size: 15, weight: .semibold))
                                    if let w = leg.weight { Text(Fmt.pct(w * 100, 0)).font(.sub).foregroundStyle(Theme.muted) }
                                }
                                Spacer()
                                Text(sell ? Fmt.cash(leg.outUsd) : Fmt.cash(leg.inUsd)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                            }
                            .frame(height: 52)
                        }
                    }
                    KCard {
                        KV("Stonks247 fee 1%", Fmt.cash(q.feeUsd))
                        KV(sell ? "You get" : "Into stocks") {
                            Text(sell ? "≈ \(Fmt.cash(q.totalOutUsd))" : Fmt.cash(q.legs.compactMap(\.inUsd).reduce(0, +)))
                                .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            if let e = store.error { ErrorBar(text: e).padding(.horizontal, -20).padding(.top, 8) }

            Group {
                switch store.phase {
                // One tap, one action. Seven transactions get signed underneath, silently, and
                // counting them out loud made that read as seven steps.
                case .signing, .submitting:
                    progress(sell ? "Selling \(store.legCount) stocks…" : "Buying \(store.legCount) stocks…")
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
    private var retrying: Bool {
        switch store.phase { case .retrying, .signing, .submitting: store.result != nil; default: false }
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(store.landed)/\(store.legCount) \(sell ? "sold" : "bought")")
                .font(.system(size: 30, weight: .semibold)).tracking(-0.8).monospacedDigit()
                .foregroundStyle(store.failedLegs.isEmpty ? Theme.green : Theme.amber)
                .padding(.bottom, 16)
            ScrollView {
                KCard {
                    ForEach(store.outcomes) { leg in
                        let sym = store.symbol(for: leg.requestId)
                        HStack(spacing: 12) {
                            Logo(url: stock(sym)?.logoURL, symbol: sym, size: 32)
                            Text(sym).font(.system(size: 15, weight: .semibold))
                            Spacer()
                            if !leg.landed, let e = leg.error {
                                Text(e).font(.sub).foregroundStyle(Theme.red).lineLimit(1)
                            }
                            Image(systemName: leg.landed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(leg.landed ? Theme.green : Theme.red)
                        }
                        .frame(height: 52)
                    }
                }
            }
            .scrollIndicators(.hidden)
            if let e = store.error, store.canRetry {
                ErrorBar(text: e).padding(.horizontal, -20).padding(.top, 10)
            }
            if !store.failedLegs.isEmpty {
                Text(retrying ? "Buying the rest…" : "The USDC for anything that failed is still in your wallet.")
                    .font(.sub).foregroundStyle(Theme.muted).padding(.top, 10)
            }
            if store.canRetry {
                BigButton(label: retrying ? "Buying \(store.failedLegs.count) more…" : "Buy the \(store.failedLegs.count) that missed", style: .cta) {
                    Task { if let w = app.auth.activeWallet { await store.retry(wallet: w) } }
                }
                .disabled(busy).padding(.top, 14)
                BigButton(label: "Done", style: .ghost) { app.settleWallet(); dismiss() }.padding(.top, 8)
            } else {
                BigButton(label: "Done", style: .white) { app.settleWallet(); dismiss() }.padding(.top, 14)
            }
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
            .padding(.vertical, 8).frame(minHeight: 64).contentShape(.rect)
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
                        hero(p)
                        holdings(p)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rebalance").font(.system(size: 15, weight: .semibold))
                                Text("Keeps every stock at its target weight").font(.sub).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text("COMING SOON").font(.system(size: 9, weight: .bold)).tracking(0.4).foregroundStyle(Theme.amber)
                                .padding(.horizontal, 6).frame(height: 17).background(Theme.amberT, in: .rect(cornerRadius: 5))
                        }
                        .padding(14).background(Theme.surface, in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                } else {
                    EmptyState(title: "This basket is closed.", subtitle: "Its stocks were sold back to USDC.")
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                if let p {
                    BigButton(label: "Close position", style: .sell) { Haptic.medium(); app.sheet = .closeBasket(p) }
                        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
                        .background(Theme.ground)
                }
            }
        }
        .background(Theme.ground)
        .task { await positions.load() }
    }

    /// Value, gain as a tinted chip, and what it cost, in one glance.
    private func hero(_ p: BasketPosition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                LogoStack(urls: p.stocks.compactMap(\.logoURL), size: 32)
                Text("\(p.stocks.count) stocks").font(.sub).foregroundStyle(Theme.muted)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(Fmt.usd(p.valueUsd)).font(.system(size: 34, weight: .semibold)).tracking(-1).monospacedDigit()
                if let g = p.pnlUsd {
                    HStack(spacing: 8) {
                        Text(Fmt.signedCash(g)).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.change(g))
                        Text(Fmt.arrow(p.pnlPct ?? 0, 2)).font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.change(g))
                            .padding(.horizontal, 7).frame(height: 22).background(g >= 0 ? Theme.greenT : Theme.redT, in: .capsule)
                    }
                }
            }
            KCard {
                KV("Paid", Fmt.cash(p.paidUsd))
                if let t = p.openedAt { KV("Opened", Fmt.date(t)) }
            }
        }
    }

    /// Each stock with its share of the basket today, so a drift from equal weight is visible.
    private func holdings(_ p: BasketPosition) -> some View {
        let rows = p.stocks.filter { ($0.valueUsd ?? 0) >= 0.01 }
        let total = rows.compactMap(\.valueUsd).reduce(0, +)
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Holdings")
            KCard {
                ForEach(rows) { h in
                    HStack(spacing: 12) {
                        Logo(url: h.logoURL, symbol: h.symbol, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.symbol).font(.system(size: 15, weight: .semibold))
                            Text(Fmt.qty(h.amount ?? 0, symbol: h.symbol)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.usd(h.valueUsd)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                            if total > 0, let v = h.valueUsd {
                                Text(Fmt.pct(v / total * 100, 1)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .frame(height: 56)
                }
            }
        }
    }
}
