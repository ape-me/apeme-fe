import SwiftUI

/// Invest in, or close, a basket: review the legs, sign them all, watch them land.
struct BasketOrderSheet: View {
    let basketId: String
    let name: String
    var tagline: String? = nil
    var logos: [URL] = []
    let sell: Bool
    let amountUsd: Double
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var store: BasketOrderStore

    init(basketId: String, name: String, tagline: String? = nil, logos: [URL] = [], sell: Bool, amountUsd: Double) {
        self.basketId = basketId; self.name = name; self.tagline = tagline; self.logos = logos
        self.sell = sell; self.amountUsd = amountUsd
        _store = State(initialValue: BasketOrderStore(basketId: basketId, name: name, sell: sell))
    }

    /// The cover names the basket; the title says what is happening to it.
    private var title: String {
        switch store.phase {
        case .done: sell ? "Closed" : "Bought"
        default: sell ? "Close position?" : "Buy basket"
        }
    }

    /// Amount on a buy, what comes back on a sell; the result shows how much of it landed.
    private var cover: some View {
        BasketCover(name: name, tagline: tagline, logos: logos) {
            HStack { Text(title).h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(busy) }
                .padding(.top, 10)
        } trailing: {
            VStack(alignment: .trailing, spacing: 2) {
                if store.result != nil {
                    Text("\(store.landed)/\(store.legCount)")
                        .font(.system(size: 26, weight: .semibold)).tracking(-0.8).monospacedDigit()
                        .foregroundStyle(store.failedLegs.isEmpty ? Theme.green : Theme.amber)
                    Text(sell ? "sold" : "bought").font(.sub).foregroundStyle(Theme.muted)
                } else if let q = store.quote {
                    Text(sell ? "≈ \(Fmt.cash(q.totalOutUsd))" : Fmt.cash(q.amountUsd))
                        .font(.system(size: 26, weight: .semibold)).tracking(-0.8).monospacedDigit().foregroundStyle(Theme.ink)
                    Text(sell ? "USDC back" : "\(q.legs.count) stocks").font(.sub).foregroundStyle(Theme.muted)
                } else if !sell {
                    Text(Fmt.cash(amountUsd))
                        .font(.system(size: 26, weight: .semibold)).tracking(-0.8).monospacedDigit().foregroundStyle(Theme.ink)
                    Text("pricing…").font(.sub).foregroundStyle(Theme.muted)
                } else {
                    Skeleton(height: 26).frame(width: 90)
                }
            }
        }
    }

    /// Quote legs carry a symbol, not a mint; the stock list already loaded gives the mark.
    private func stock(_ symbol: String?) -> Stock? {
        guard let symbol else { return nil }
        return app.stocksByMint.values.first { $0.symbol == symbol }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            content.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
        }
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
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 10) {
                        Skeleton(height: 24).frame(width: 24)
                        Skeleton(height: 14).frame(width: 64)
                        Spacer()
                        Skeleton(height: 14).frame(width: 48)
                    }
                    .frame(height: 40)
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
                Text(sell ? "Pricing every stock in the basket…" : "Getting prices for the stocks…")
                    .font(.sub).foregroundStyle(Theme.muted).padding(.top, 14)
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

    /// The order as a ledger, the way every broker shows one: a line per stock, the fee, a
    /// heavier rule, and the one number that matters. Hairlines only; nothing in a box.
    private func review(_ q: BasketQuote) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(q.legs) { leg in
                        ledgerRow(symbol: leg.symbol ?? "—") {
                            Text(sell ? Fmt.cash(leg.outUsd) : Fmt.cash(leg.inUsd))
                                .font(.system(size: 15, weight: .medium)).monospacedDigit().foregroundStyle(Theme.ink)
                        }
                    }
                    HStack {
                        Text("Stonks247 fee 1% · included").font(.system(size: 15)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(Fmt.cash(q.feeUsd)).font(.system(size: 15, weight: .medium)).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    .frame(height: 40)
                    Rectangle().fill(Theme.ink.opacity(0.4)).frame(height: 1.5)
                    HStack {
                        Text(sell ? "You get" : "You pay").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Text(sell ? "≈ \(Fmt.cash(q.totalOutUsd))" : Fmt.cash(q.amountUsd))
                            .font(.system(size: 17, weight: .semibold)).monospacedDigit()
                    }
                    .frame(height: 48)
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
                        // The page checks this too, but the balance can move between the two.
                        if amountUsd > app.cashUsd + 0.0001 {
                            store.error = "You have \(Fmt.cash(app.cashUsd)) USDC. Lower the amount or deposit first."; return
                        }
                        Haptic.medium()
                        Task { await store.send(wallet: w, amountUsd: amountUsd, taker: t) }
                    }
                }
            }
            .padding(.top, 14)
        }
    }

    /// One line of the ledger: a small mark, the symbol, whatever belongs on the right, and a
    /// hairline under it. A failed leg's reason sits under the symbol in red.
    private func ledgerRow<Trailing: View>(symbol: String, note: String? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Logo(url: stock(symbol)?.logoURL, symbol: symbol, size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(symbol).font(.system(size: 15, weight: .semibold))
                    if let note { Text(note).font(.system(size: 12)).foregroundStyle(Theme.red).lineLimit(1) }
                }
                Spacer()
                trailing()
            }
            .frame(minHeight: 40)
            Rectangle().fill(Theme.line).frame(height: 1)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.outcomes) { leg in
                        let sym = store.symbol(for: leg.requestId)
                        ledgerRow(symbol: sym, note: leg.landed ? nil : leg.error) {
                            Image(systemName: leg.landed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 17)).foregroundStyle(leg.landed ? Theme.green : Theme.red)
                        }
                    }
                    Rectangle().fill(Theme.ink.opacity(0.4)).frame(height: 1.5)
                    HStack {
                        Text("\(store.landed) of \(store.legCount) \(sell ? "sold" : "bought")").font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(store.failedLegs.isEmpty ? Theme.green : Theme.amber)
                        Spacer()
                    }
                    .frame(height: 48)
                }
            }
            .scrollIndicators(.hidden)
            if let e = store.error, store.canRetry {
                ErrorBar(text: e).padding(.horizontal, -20).padding(.top, 10)
            }
            if !store.failedLegs.isEmpty, !store.ranOutOfMoney {
                Text(retrying ? "Buying the rest…" : "The USDC for anything that failed is still in your wallet.")
                    .font(.sub).foregroundStyle(Theme.muted).padding(.top, 10)
            }
            if store.ranOutOfMoney {
                BigButton(label: "Deposit USDC", style: .cta) { dismiss(); app.sheet = .deposit }.padding(.top, 14)
                BigButton(label: "Done", style: .ghost) { app.settleWallet(); dismiss() }.padding(.top, 8)
            } else if store.canRetry {
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
        ZStack(alignment: .top) {
            ScrollView {
                if let p {
                    VStack(alignment: .leading, spacing: 0) {
                        cover(p)
                        VStack(alignment: .leading, spacing: 22) {
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
                        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 24)
                    }
                    .containerRelativeFrame(.horizontal, alignment: .leading)
                } else {
                    EmptyState(title: "This basket is closed.", subtitle: "Its stocks were sold back to USDC.").padding(.top, 56)
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
            HStack(spacing: 10) { BackButton(); Spacer() }
                .padding(.horizontal, 12).frame(height: 56)
        }
        .background(Theme.ground)
        .task { await positions.load() }
    }

    /// The cover with what the position is worth now, and under it what it cost, how it has
    /// done, since when, and of how many stocks.
    private func cover(_ p: BasketPosition) -> some View {
        BasketCover(name: p.name, logos: p.stocks.prefix(5).compactMap(\.logoURL), stats: [
            .init(label: "Paid", value: Fmt.cash(p.paidUsd)),
            .init(label: "Return", value: Fmt.trailingArrow(p.pnlPct, 2), color: Theme.change(p.pnlPct)),
            .init(label: "Since", value: p.openedAt.map { Fmt.monthDay($0) } ?? "—"),
            .init(label: "Stocks", value: "\(p.stocks.count)"),
        ]) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(Fmt.usd(p.valueUsd)).font(.system(size: 26, weight: .semibold)).tracking(-0.8).monospacedDigit().foregroundStyle(Theme.ink)
                if let g = p.pnlUsd {
                    Text("\(Fmt.signedCash(g)) · \(Fmt.arrow(p.pnlPct ?? 0, 2))")
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.change(g))
                        .padding(.horizontal, 8).frame(height: 24).background(g >= 0 ? Theme.greenT : Theme.redT, in: .capsule)
                }
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
                                Text(String(format: "%.1f%% of it", v / total * 100)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .frame(height: 56)
                }
            }
        }
    }
}
