import SwiftUI

/// Buy / Sell / Ape: what you pay, what you get, one button. Fees live under "Details".
struct TradeSheetView: View {
    enum Asset {
        case stock(Stock)
        case token(TokenCard, StockRef?)
        case holding(Holding)

        var mint: String { switch self { case .stock(let s): s.mint; case .token(let t, _): t.mint; case .holding(let h): h.mint } }
        var symbol: String { switch self { case .stock(let s): s.symbol; case .token(let t, _): t.displaySymbol; case .holding(let h): h.symbol } }
        var priceUsd: Double? { switch self { case .stock(let s): s.priceUsd; case .token(let t, _): t.priceUsd; case .holding(let h): h.priceUsd } }
        var imageURL: URL? { switch self { case .stock(let s): s.logoURL; case .token(let t, _): t.imageURL; case .holding(let h): h.imageURL } }
        var isStock: Bool { switch self { case .stock: true; case .token: false; case .holding(let h): h.kind == "stock" } }
        var isPreIPO: Bool { if case .stock(let s) = self { return s.isPreIPO }; return false }
        var onSymbol: String? { switch self { case .token(_, let r): r?.symbol; case .holding(let h): h.quoteSymbol; default: nil } }
    }

    let side: TradeStore.Side
    let asset: Asset

    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: TradeStore
    @State private var amount = ""          // dollars typed (buy and sell)
    @State private var pct: Double? = nil    // sell chip, for the label only
    @State private var reviewing = false
    @State private var limit = false
    @State private var trigger = ""
    @State private var settingPrice = false
    @State private var orderQuote: OrderQuote?
    @State private var placing = false
    @State private var livePulse = false
    /// A limit sell is priced in tokens: you choose how many to sell and at what price. Dollars
    /// would be computed at today's price and would be wrong the moment the trigger differs.
    @State private var tokens = ""

    init(side: TradeStore.Side, asset: Asset) {
        self.side = side; self.asset = asset
        let holding: Holding? = { if case .holding(let h) = asset { return h }; return nil }()
        _store = State(initialValue: TradeStore(side: side, mint: asset.mint, symbol: asset.symbol, priceUsd: asset.priceUsd, holding: holding,
                                                 priority: Auth.shared.settings.priority ?? "normal"))
    }

    /// Back on the review step after a failed attempt, same store, same numbers.
    init(resume r: TradeResume) {
        self.side = r.side; self.asset = r.asset
        _store = State(initialValue: r.store)
        _amount = State(initialValue: r.amount)
        _pct = State(initialValue: r.pct)
        _reviewing = State(initialValue: true)
    }

    private var verb: String { side == .sell ? "Sell" : asset.isStock ? "Buy" : "Ape" }
    private var usd: Double { Double(amount) ?? 0 }
    private var settings: Me.Settings { app.auth.settings }
    private var cash: Double { app.cashUsd }
    /// Solved backwards: with balance B, the most they can *receive* is (B − rent) / 1.01, since
    /// our 1% and the one-time account fee are charged on top of whatever they type.
    private var rentIfFirst: Double { holdsAlready ? 0 : 0.25 }
    private var holdsAlready: Bool { (app.wallet?.positions ?? []).contains { $0.mint == asset.mint } }
    private var maxCash: Double { max(0, floor(((cash - rentIfFirst) / 1.01) * 100) / 100) }

    /// What the order will actually cost, before the quote confirms it to the cent.
    private func estimatedTotal(_ receive: Double) -> Double { receive * 1.01 + rentIfFirst }
    /// The charge the quote reports: `totalUsd` on a buy, the gross on a sell.
    private func charged(_ q: Quote) -> Double { q.totalUsd ?? q.inUsd ?? 0 }
    private var busy: Bool { [.signing, .submitting, .confirming].contains(store.phase) }
    private var sellValue: Double { store.holding?.valueUsd ?? 0 }
    private var sellQty: Double { sellValue > 0 ? (store.holding?.amount ?? 0) * min(usd, sellValue) / sellValue : 0 }
    private var hasAmount: Bool { usd > 0 }
    /// Which issuers are off-limits is the BE's to say, so the day Jupiter supports transfer-fee
    /// mints this opens up with no release.
    private var canLimit: Bool {
        guard asset.isStock else { return false }
        let issuer = app.stocksByMint[asset.mint]?.issuer ?? (asset.isPreIPO ? "prestocks" : "")
        return OrdersStore.shared.config.allows(issuer: issuer)
    }
    private var triggerUsd: Double { Double(trigger) ?? 0 }
    private var limitSell: Bool { limit && side == .sell }
    private var tokenQty: Double { Double(tokens) ?? 0 }
    private var heldQty: Double { store.holding?.amount ?? 0 }
    /// What the BE weighs against the minimum: the position's value at today's price.
    private var limitSellUsd: Double { heldQty > 0 ? sellValue * tokenQty / heldQty : 0 }
    /// What the order would actually return if it fills at the trigger.
    private var proceedsAtTrigger: Double { tokenQty * triggerUsd }

    /// A buy has to sit below spot and a sell above it, by whatever gap the BE asks for.
    /// Otherwise the keeper fills it on the next pass and it is a market order dodging the fee.
    private var gap: Double { Double(OrdersStore.shared.config.minGapBps ?? 0) / 10_000 }
    private var triggerCeiling: Double { spot * (1 - gap) }
    private var triggerFloor: Double { spot * (1 + gap) }
    private var triggerIsValid: Bool {
        guard triggerUsd > 0, spot > 0 else { return false }
        return side == .buy ? triggerUsd < triggerCeiling : triggerUsd > triggerFloor
    }
    private var triggerProblem: String? {
        guard triggerUsd > 0, spot > 0, !triggerIsValid else { return nil }
        return side == .buy
            ? "Limit buys wait for a cheaper price. Set it below \(Fmt.usd(triggerCeiling)), or use Market to buy now."
            : "Limit sells wait for a higher price. Set it above \(Fmt.usd(triggerFloor)), or use Market to sell now."
    }
    /// Live where a socket is feeding it: the stock page writes price frames into the index, so
    /// the sheet reads the same number the page behind it is showing rather than a snapshot.
    private var spot: Double { app.stocksByMint[asset.mint]?.priceUsd ?? asset.priceUsd ?? 0 }
    private var awayPct: Double { spot > 0 && triggerUsd > 0 ? (triggerUsd - spot) / spot * 100 : 0 }


    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch store.phase {
            case .confirmed: ScrollView { done }.scrollIndicators(.hidden)
            case .requoted: requoted
            default:
                if settingPrice { priceStep }
                else if reviewing { ScrollView { limit ? AnyView(orderReview) : AnyView(review) }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize) }
                else { form }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .task { if app.wallet == nil { await app.loadWallet() } }
        .task { await OrdersStore.shared.loadConfig() }
        .onChange(of: amount) { _, _ in store.reset() }
        .onChange(of: pct) { _, _ in store.reset() }
        .onChange(of: scenePhase) { _, p in if p == .active { Task { await store.refresh() } } }
        .onChange(of: store.phase) { old, p in
            // Soft ticks while the price loads, one firmer tick when it lands.
            if old == .quoting, p == .ready, reviewing { Haptic.light() }
        }
        .onChange(of: store.error) { _, e in if let e, store.phase == .failed, app.tradeInFlight == nil, reviewing { app.show(e, error: true) } }
    }

    private func requote() {
        switch side {
        case .buy: store.requote(usd: usd, estimatedTotal: estimatedTotal(usd), taker: app.walletAddress, cashUsd: cash)
        case .sell:
            guard let h = store.holding, let raw = h.raw, let r = Decimal(string: raw), let value = h.valueUsd, value > 0, usd > 0 else { store.requote(rawAmount: nil, taker: app.walletAddress, cashUsd: 0); return }
            // More than they hold → stop, like Buy does. All of it → the whole position, so no dust is left.
            if usd > value + 0.005 { store.requote(rawAmount: "over", taker: app.walletAddress, cashUsd: 0); return }
            if usd >= value - 0.005 || pct == 100 { store.requote(rawAmount: raw, taker: app.walletAddress, cashUsd: 0); return }
            var v = r * Decimal(usd) / Decimal(value)
            var out = Decimal(); NSDecimalRound(&out, &v, 0, .down)
            store.requote(rawAmount: "\(out)", taker: app.walletAddress, cashUsd: 0)
        }
    }

    // MARK: Amount

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 14) {
                assetImage(48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(verb) \(asset.symbol)").h2Text()
                    Text(side == .sell ? "You hold \(Fmt.qty(store.holding?.amount ?? 0, symbol: asset.symbol)) · \(Fmt.usd(store.holding?.valueUsd))" : "Cash \(Fmt.cash(cash))")
                        .font(.system(size: 15)).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(busy)
        }
        .padding(.top, 14)
    }

    @ViewBuilder private func assetImage(_ size: CGFloat) -> some View {
        if asset.isStock { Logo(url: asset.imageURL, symbol: asset.symbol, size: size) } else { Avatar(url: asset.imageURL, symbol: asset.symbol, size: size) }
    }

    @ViewBuilder private var modeTabs: some View {
        if canLimit {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach([false, true], id: \.self) { isLimit in
                        Button {
                            Haptic.selection(); limit = isLimit; store.reset(); orderQuote = nil
                        } label: {
                            VStack(spacing: 8) {
                                Text(isLimit ? "Limit" : "Market")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(limit == isLimit ? Theme.ink : Theme.faint)
                                Rectangle().fill(limit == isLimit ? Theme.ink : .clear).frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain).frame(maxWidth: .infinity)
                    }
                }
                Text(limit ? "Fills only at your price or better. Nothing is charged until it does."
                           : "Fills now at the best price available.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 14)
        }
    }

    /// The price is a row that pushes into its own screen — squeezed beside the amount it reads
    /// as a form field, which is the whole reason the first attempt felt cheap.
    private var triggerRow: some View {
        Button { Haptic.light(); settingPrice = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("When price hits").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Text(triggerUsd > 0 ? Fmt.usd(triggerUsd) : "Set a price")
                        .font(.system(size: 19, weight: .bold)).monospacedDigit()
                        .foregroundStyle(triggerUsd > 0 ? Theme.ink : Theme.faint)
                }
                Spacer()
                if triggerUsd > 0 {
                    Text("\(awayPct >= 0 ? "+" : "−")\(String(format: "%.1f", abs(awayPct)))%")
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(awayPct >= 0 ? Theme.amber : Theme.green)
                }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 16).frame(height: 64)
            .background(Theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(PressScale())
        .padding(.top, 16)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            modeTabs
            Spacer(minLength: 12)
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    if limitSell { assetImage(36) } else { Image("usdc").resizable().frame(width: 36, height: 36).clipShape(.circle) }
                    Text(limitSell ? (tokens.isEmpty ? "0" : tokens) : (amount.isEmpty ? "0" : amount))
                        .font(.amount).tracking(-2.8).monospacedDigit().foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
                if limitSell {
                    HStack(spacing: 5) {
                        if triggerUsd > 0, tokenQty > 0 {
                            Text("you'd get").foregroundStyle(Theme.muted)
                            Text(Fmt.cash(proceedsAtTrigger)).foregroundStyle(Theme.green).fontWeight(.bold)
                            Text("at \(Fmt.usd(triggerUsd))").foregroundStyle(Theme.muted)
                        } else {
                            Text("you hold").foregroundStyle(Theme.muted)
                            Text(Fmt.qty(heldQty, symbol: asset.symbol)).foregroundStyle(Theme.green).fontWeight(.bold)
                            Text("·").foregroundStyle(Theme.faint)
                            Text(Fmt.usd(spot)).foregroundStyle(Theme.green).fontWeight(.bold)
                        }
                    }
                    .font(.system(size: 15)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                } else if side == .sell, hasAmount, sellValue > 0 {
                    Text("≈ \(Fmt.qty(sellQty, symbol: asset.symbol)) · \(Fmt.n(min(100, usd / sellValue * 100).rounded()))%").font(.system(size: 15)).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity)
            if limit { triggerRow }
            Spacer(minLength: 12)
            if side == .buy {
                chips((settings.quickBuyUsd ?? [10, 25, 50, 100]).map { ("$" + Fmt.n($0), nil, $0) } + [("Max", nil, maxCash)], selected: usd) { amount = String(format: $0 == maxCash ? "%.2f" : "%g", $0); pct = nil }
            } else if limitSell {
                chips((settings.quickSellPct ?? [25, 50, 100]).map { p in (Fmt.n(p) + "%", Fmt.qty(heldQty * p / 100, symbol: ""), heldQty * p / 100) }, selected: tokenQty) { q in
                    tokens = Fmt.plain(q)
                    pct = abs(q - heldQty) < heldQty * 0.0001 ? 100 : nil
                }
            } else {
                chips((settings.quickSellPct ?? [25, 50, 100]).map { p in (Fmt.n(p) + "%", Fmt.usd(sellValue * p / 100), sellValue * p / 100) }, selected: usd) { v in
                    amount = String(format: "%.2f", floor(v * 100) / 100); pct = abs(v - sellValue) < 0.005 ? 100 : nil
                }
            }
            Spacer(minLength: 12)
            Numpad { key in
                pct = nil
                if limitSell {
                    switch key {
                    case "⌫": tokens = String(tokens.dropLast())
                    case ".": if !tokens.contains(".") { tokens = (tokens.isEmpty ? "0" : tokens) + "." }
                    default: if tokens.count < 12 { tokens = tokens == "0" ? key : tokens + key }
                    }
                    return
                }
                switch key {
                case "⌫": amount = String(amount.dropLast())
                case ".": if !amount.contains(".") { amount = (amount.isEmpty ? "0" : amount) + "." }
                default:
                    let d = amount.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
                    if amount.count < 8, !amount.contains(".") || d < 2 { amount = amount == "0" ? key : amount + key }
                }
            }
            errorBox.padding(.top, 12)
            Spacer(minLength: 16)
            primary
        }
        .frame(maxHeight: .infinity)
    }

    private func chips(_ items: [(String, String?, Double)], selected: Double, pick: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { label, sub, v in
                let on = abs(v - selected) <= max(abs(v), abs(selected)) * 0.001 + 1e-9
                Button { Haptic.selection(); pick(v) } label: {
                    VStack(spacing: 2) {
                        Text(label).font(.system(size: 14, weight: .semibold))
                        if let sub { Text(sub).font(.system(size: 11, weight: .medium)).foregroundStyle(on ? skin.accent.opacity(0.8) : Theme.muted) }
                    }
                    .monospacedDigit()
                    .foregroundStyle(on ? skin.accent : Theme.ink)
                    .frame(maxWidth: .infinity).frame(height: sub == nil ? 44 : 52)
                    .background(on ? skin.accentTint : Theme.surface2, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// "Buy $25 · [logo] NVDAX" — the asset's mark in the button instead of a long name.
    private func tradeButton(_ prefix: String, style: BigButton.Style, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(prefix)
                assetImage(22)
                Text(asset.symbol)
            }
            .font(.system(size: 17, weight: .semibold)).tracking(-0.2).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(style == .sell ? AnyShapeStyle(Theme.sellGradient) : AnyShapeStyle(Theme.buyGradient), in: .capsule)
        }
        .buttonStyle(PressScale())
    }

    /// The two things a first-timer must know: a big premium, or a big price impact. Nothing else up front.
    @ViewBuilder private var notes: some View {
        if let q = store.quote {
            if side == .buy, asset.isStock, let p = q.premiumPct, p > 5 {
                note("Trading \(String(format: "%.0f", p))% above \(asset.isPreIPO ? "its fair value" : "the Nasdaq price").")
            }
            if let i = q.priceImpactPct, i > 2 {
                note("Thin market: you're paying \(String(format: "%.1f", i))% above the current price.")
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.sub).foregroundStyle(Theme.amber).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10).background(Theme.amberT, in: .rect(cornerRadius: 10))
    }

    /// Errors go to the toast; the sheet only keeps the debug request id.
    @ViewBuilder private var errorBox: some View {
        #if DEBUG
        if reviewing, store.phase == .failed, let r = store.requestId {
            Text("req \(r)").font(.system(size: 10)).foregroundStyle(Theme.faint).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }
        #endif
    }

    /// Amount step button. Purely local — nothing is fetched until Review order.
    @ViewBuilder private var primary: some View {
        if limit { limitPrimary } else { marketPrimary }
    }

    /// Everything a limit order is gated on, in one place, reading the token amount when that is
    /// what the sheet is asking for and dollars when it is not.
    @ViewBuilder private var limitPrimary: some View {
        let min = OrdersStore.shared.minUsd
        let value = limitSell ? limitSellUsd : usd
        if limitSell, tokenQty <= 0 {
            BigButton(label: "Enter an amount", style: .off) {}
        } else if !limitSell, usd <= 0 {
            BigButton(label: "Enter an amount", style: .off) {}
        } else if limitSell, tokenQty > heldQty * 1.0001 {
            BigButton(label: "You hold \(Fmt.qty(heldQty, symbol: asset.symbol)) · Sell all", style: .white) {
                Haptic.light(); tokens = Fmt.plain(heldQty)
            }
        } else if limitSell, let min, sellValue < min - 0.005 {
            // The floor is measured on what the position is worth today, not on what the trigger
            // would return — Jupiter values the order when it is placed. Saying only the figure
            // read as the proceeds, which is a different number and a worrying one.
            VStack(spacing: 10) {
                Text("A limit order needs \(Fmt.cash(min)). This is worth \(Fmt.cash(sellValue)) at today's price — that's what counts, not what your trigger would return.")
                    .font(.sub).foregroundStyle(Theme.muted).lineSpacing(2)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                BigButton(label: "Sell at market instead", style: .white) {
                    Haptic.light(); limit = false
                    amount = String(format: "%.2f", floor(sellValue * 100) / 100); pct = 100
                }
            }
        } else if let min, value < min {
            // A dead grey button states the rule and leaves the user stuck. Give the way out:
            // top the order up to the floor when the cash is there, or go to market when not.
            VStack(spacing: 10) {
                Text(limitSell
                     ? "A limit order needs \(Fmt.cash(min)) — that's the value at today's price, not what your trigger would return."
                     : "A limit order needs \(Fmt.cash(min)). Below that Jupiter won't hold it.")
                    .font(.sub).foregroundStyle(Theme.muted).lineSpacing(2)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if !limitSell, min * (1 + OrdersStore.shared.config.buyFeeRate) + (OrdersStore.shared.config.accountCostUsd ?? 0) <= cash + 0.000001 {
                    BigButton(label: "Make it \(Fmt.cash(min))", style: .buy) {
                        Haptic.light(); amount = String(format: "%g", min)
                    }
                } else {
                    BigButton(label: side == .buy ? "Buy at market instead" : "Sell at market instead", style: .white) {
                        Haptic.light(); limit = false
                        if limitSell { amount = String(format: "%.2f", floor(sellValue * 100) / 100); pct = 100 }
                    }
                }
            }
        } else if triggerUsd <= 0 {
            BigButton(label: "Set a trigger price", style: .off) { Haptic.light(); settingPrice = true }
        } else if !triggerIsValid {
            VStack(spacing: 10) {
                Text(triggerProblem ?? "").font(.sub).foregroundStyle(Theme.red).lineSpacing(2)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                BigButton(label: "Change the price", style: .white) { Haptic.light(); settingPrice = true }
            }
        } else if let max = OrdersStore.shared.config.maxOpen, OrdersStore.shared.open.count >= max {
            BigButton(label: "\(max) open orders is the limit", style: .off) {}
        } else if side == .buy, usd > cash + 0.000001 {
            // Only the obvious case locally — the on-chain cost is the BE's to price, and its
            // insufficient_usdc carries the exact shortfall.
            BigButton(label: "Deposit to place this", style: .white) { dismiss(); app.sheet = .deposit }
        } else {
            BigButton(label: "Review order", style: side == .sell ? .sell : .buy) {
                Haptic.light(); reviewing = true; Task { await loadOrderQuote() }
            }
        }
    }

    /// Market: purely local, nothing is fetched until Review order.
    @ViewBuilder private var marketPrimary: some View {
        if usd <= 0 { BigButton(label: "Enter an amount", style: .off) {} }
        else if side == .buy, estimatedTotal(usd) > cash + 0.000001 { BigButton(label: "Deposit to buy", style: .white) { dismiss(); app.sheet = .deposit } }
        else if side == .sell, usd > sellValue + 0.005 { BigButton(label: "You hold \(Fmt.cash(sellValue)) · Sell all", style: .white) { amount = String(format: "%.2f", floor(sellValue * 100) / 100); pct = 100 } }
        else { BigButton(label: "Review order", style: side == .sell ? .sell : .buy) { Haptic.light(); reviewing = true; requote() } }
    }

    // MARK: Limit — price step and order review

    /// Phantom's Set Limit Price in our clothes: one number, the distance from spot beneath it,
    /// offsets sitting directly on the keys.
    private var priceStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back") { settingPrice = false }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Set trigger price").h3Text()
                    HStack(spacing: 5) {
                        Circle().fill(Theme.green).frame(width: 6, height: 6).opacity(livePulse ? 0.35 : 1)
                        Text("\(asset.symbol) now").font(.sub).foregroundStyle(Theme.muted)
                        Text(Fmt.usd(spot))
                            .font(.system(size: 15, weight: .bold)).monospacedDigit()
                            .foregroundStyle(Theme.green)
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.top, 8)
            Spacer(minLength: 20)
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.faint)
                    Text(trigger.isEmpty ? "0" : trigger).font(.amount).tracking(-2.8).monospacedDigit().foregroundStyle(Theme.ink)
                }
                Text(triggerUsd > 0 ? "\(awayPct >= 0 ? "+" : "−")\(String(format: "%.2f", abs(awayPct)))%  ⇅" : "0%  ⇅")
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(triggerUsd <= 0 ? Theme.faint : !triggerIsValid ? Theme.red : awayPct >= 0 ? Theme.amber : Theme.green)
                if let problem = triggerProblem {
                    Text(problem).font(.sub).foregroundStyle(Theme.red).lineSpacing(2)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 20)
            offsetChips
            Numpad { key in
                switch key {
                case "⌫": trigger = String(trigger.dropLast())
                case ".": if !trigger.contains(".") { trigger = (trigger.isEmpty ? "0" : trigger) + "." }
                default:
                    let d = trigger.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
                    if trigger.count < 10, !trigger.contains(".") || d < 2 { trigger = trigger == "0" ? key : trigger + key }
                }
            }
            .padding(.top, 8)
            Spacer(minLength: 12)
            BigButton(label: "Set", style: triggerIsValid ? (side == .sell ? .sell : .buy) : .off) {
                guard triggerIsValid else { return }
                Haptic.light(); settingPrice = false
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.easeOut(duration: 0.3), value: spot)
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever()) { livePulse = true } }
    }

    /// Offsets from spot, the way every exchange offers them — a trigger in one tap.
    private var offsetChips: some View {
        let offsets: [(String, Double)] = side == .buy
            ? [("−1%", -1), ("−2%", -2), ("−5%", -5), ("−10%", -10)]
            : [("+1%", 1), ("+2%", 2), ("+5%", 5), ("+10%", 10)]
        return HStack(spacing: 8) {
            ForEach(offsets, id: \.0) { label, pct in
                Button {
                    Haptic.selection()
                    trigger = String(format: "%.2f", spot * (1 + pct / 100))
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Theme.surface2, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Buys give USDC at 6dp. Sells give raw token units — and only the share the user actually
    /// asked for: the amount is typed in dollars, so it has to be scaled against the position's
    /// value, or every partial limit sell would quietly sell the whole holding.
    private var orderAmountRaw: String? {
        if side == .buy { return String(Int64((usd * 1_000_000).rounded())) }
        guard let h = store.holding, let raw = h.raw, !raw.isEmpty, raw != "0",
              let total = Decimal(string: raw), h.amount > 0, tokenQty > 0 else { return nil }
        // All of it, within rounding: send the exact balance so no dust is stranded.
        if tokenQty >= h.amount * 0.9999 || pct == 100 { return raw }
        // Scale the raw balance, never uiAmount x 10^decimals — on a rebased xStock the
        // multiplier makes those differ and the order would ask for more than is held.
        var scaled = total * Decimal(tokenQty) / Decimal(h.amount)
        var floored = Decimal()
        NSDecimalRound(&floored, &scaled, 0, .down)
        return floored > 0 ? "\(floored)" : nil
    }

    private func loadOrderQuote() async {
        orderQuote = nil
        guard let addr = app.walletAddress else { return }
        guard let raw = orderAmountRaw else {
            app.show("Couldn't read your \(asset.symbol) balance. Pull to refresh and try again.", error: true)
            reviewing = false
            return
        }
        do {
            orderQuote = try await API.shared.orderQuote(wallet: addr, mint: asset.mint,
                                                         side: side == .buy ? "buy" : "sell",
                                                         amountRaw: raw, triggerUsd: triggerUsd)
        } catch {
            OrdersStore.shared.adopt(error)
            store.error = OrdersStore.message(error)
            app.show(store.error ?? "Couldn't price that order.", error: true)
            reviewing = false
        }
    }

    /// A limit order reviews its own way: what gets reserved leads, because nothing is spent.
    private var orderReview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back") { reviewing = false }.disabled(placing)
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(placing)
            }
            VStack(spacing: 10) {
                assetImage(64)
                Text(side == .buy ? "Buy $\(amount) at \(Fmt.usd(triggerUsd))"
                                  : "Sell \(Fmt.qty(tokenQty, symbol: asset.symbol)) at \(Fmt.usd(triggerUsd))")
                    .h1Text().multilineTextAlignment(.center)
                Text("\(asset.symbol) price \(Fmt.usd(spot))").font(.system(size: 15)).monospacedDigit().foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity).padding(.top, 26)
            if let q = orderQuote {
                VStack(spacing: 0) {
                    row(side == .buy ? "You buy" : "You sell",
                        side == .buy ? "\(Fmt.cash(q.orderUsd)) of \(asset.symbol)" : Fmt.qty(tokenQty, symbol: asset.symbol),
                        .outcome)
                    if side == .sell {
                        Divider().overlay(Theme.line)
                        row("You'd get", Fmt.cash(proceedsAtTrigger))
                    }
                    Divider().overlay(Theme.line)
                    row("When price hits", Fmt.usd(q.triggerUsd))
                    Divider().overlay(Theme.line)
                    row("Price now", Fmt.usd(spot), .reference)
                    if side == .sell, let f = q.fee, !f.isFree {
                        Divider().overlay(Theme.line)
                        feeLine(f)
                    }
                    if side == .buy, let cost = q.costUsd, cost > 0 {
                        Divider().overlay(Theme.line)
                        costLine(cost, deposit: q.depositUsd, account: q.accountUsd)
                        Divider().overlay(Theme.line)
                        row("Total", Fmt.cash(q.totalUsd), .outcome)
                    }
                }
                .padding(.top, 28)
                Color.clear.frame(height: 24)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(side == .buy ? "\(Fmt.cash(q.totalUsd ?? q.escrowUsd)) leaves your wallet" : "\(Fmt.cash(proceedsAtTrigger)) if it fills")
                            .font(.system(size: 20, weight: .semibold)).tracking(-0.4).monospacedDigit()
                        Text("at \(Fmt.usd(q.triggerUsd)) · \(awayPct >= 0 ? "+" : "−")\(String(format: "%.1f", abs(awayPct)))% from now")
                            .font(.sub).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image("usdc").resizable().frame(width: 18, height: 18).clipShape(.circle)
                        Text("USDC · \(Fmt.cash(cash))").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    }
                    .padding(.horizontal, 11).frame(height: 32).background(Theme.surface2, in: .capsule)
                }
                Group {
                    if placing {
                        HStack(spacing: 10) { ProgressView().tint(.white); Text("Placing…").font(.system(size: 17, weight: .semibold)) }
                            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                            .background(side == .sell ? AnyShapeStyle(Theme.sellGradient) : AnyShapeStyle(Theme.buyGradient), in: .capsule)
                    } else {
                        BigButton(label: "Place order", style: side == .sell ? .sell : .buy) { Haptic.medium(); Task { await placeOrder(q) } }
                    }
                }
                .padding(.top, 14)
            } else {
                VStack(spacing: 0) {
                    HStack { Text(side == .buy ? "You buy" : "You sell").font(.system(size: 15)).foregroundStyle(Theme.muted); Spacer(); Shimmer().frame(width: 140, height: 16) }.frame(height: 52)
                    Divider().overlay(Theme.line)
                    row("When price hits", Fmt.usd(triggerUsd))
                }
                .padding(.top, 28)
                BigButton(label: "Pricing your order…", style: .off) {}.padding(.top, 20)
            }
        }
    }

    /// Solana's charges, on one line. Two rows with a paragraph each said the same thing at four
    /// times the length, next to a "No fee" row that read as a contradiction.
    private func costLine(_ cost: Double, deposit: Double?, account: Double?) -> some View {
        _ = account
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Solana costs").font(.system(size: 15)).foregroundStyle(Theme.muted)
                Spacer()
                Text(Fmt.cash(cost)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
            if let d = deposit, d > 0 {
                Text("\(Fmt.cash(d)) comes back").font(.sub).foregroundStyle(Theme.faint)
            }
        }
        .padding(.vertical, 12)
    }

    /// A free buy is worth saying out loud, not hiding.
    private func feeLine(_ f: OrderQuote.Fee?) -> some View {
        let bps = f?.bps ?? (side == .buy ? 0 : 150)
        let free = (f?.totalUsd ?? 0) <= 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Fee").font(.system(size: 15)).foregroundStyle(Theme.muted)
                Spacer()
                Text(free ? "No fee" : Fmt.cash(f?.totalUsd))
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(free ? Theme.green : Theme.amber)
            }
            Text(free
                 ? "Limit buys are free. You pay only for the stock."
                 : "\(String(format: "%g", Double(bps) / 100))% taken from the proceeds when it fills — cancel and nothing is charged.")
                .font(.sub).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    private func placeOrder(_ q: OrderQuote) async {
        guard let w = app.auth.activeWallet, let addr = app.walletAddress else { app.show("Sign in first.", error: true); return }
        placing = true
        defer { placing = false }
        guard let raw = orderAmountRaw else { app.show("Couldn't read your balance.", error: true); return }
        do {
            try await OrdersStore.shared.place(wallet: w, address: addr, mint: asset.mint,
                                               side: side == .buy ? "buy" : "sell",
                                               amountRaw: raw, triggerUsd: triggerUsd)
            Haptic.success()
            dismiss()
            app.show("Order placed · \(asset.symbol) at \(Fmt.usd(triggerUsd))",
                     image: ToastImage(url: asset.imageURL, symbol: asset.symbol, isStock: asset.isStock))
        } catch {
            app.show(OrdersStore.message(error), error: true)
        }
    }

    // MARK: Details (shared by review + success)

    @State private var showDetails = false

    @ViewBuilder private func details(_ q: Quote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeOut(duration: 0.15)) { showDetails.toggle() } } label: {
                HStack(spacing: 4) {
                    Text("Details").font(.sub).foregroundStyle(Theme.muted)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(showDetails ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            if showDetails {
                KCard {
                    if side == .buy { KV("Buys of \(asset.symbol)", Fmt.cash(q.swapUsd ?? q.outUsd)) }
                    KV("ApeMe fee", Fmt.cash(q.fee?.usd ?? 0))
                    if let f = q.issuerFee, let bps = f.bps, bps > 0 { KV("Issuer fee \(String(format: "%g", Double(bps) / 100))%", Fmt.cash(f.usd ?? 0)) }
                    if let rent = rentUsd(q) {
                        KV("One-time network fee", Fmt.cash(rent))
                        Text("Charged by Solana to open \(asset.symbol) in your wallet, not by ApeMe. Never again for this token.")
                            .font(.system(size: 12)).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                    }
                    KV("Gas", "Free")
                    KV("Price impact") {
                        Text(String(format: "%.2f%%", q.priceImpactPct ?? 0)).foregroundStyle((q.priceImpactPct ?? 0) > 2 ? Theme.amber : Theme.ink)
                    }
                    KV("Max price move", "\(Double(q.slippageBps ?? 100) / 100)%")
                }
            }
        }
    }

    // MARK: Review

    private var review: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back") { reviewing = false }.disabled(busy)
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(busy)
            }
            VStack(spacing: 10) {
                assetImage(64)
                Text(side == .buy ? "\(verb) $\(amount) of \(asset.symbol)" : "Sell $\(amount) of \(asset.symbol)").h1Text().multilineTextAlignment(.center)
                Text("\(asset.symbol) price \(Fmt.usd(asset.priceUsd))").font(.system(size: 15)).monospacedDigit().foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity).padding(.top, 26)
            if store.quote == nil {
                VStack(spacing: 0) {
                    HStack { Text(side == .buy ? "Receive" : "Selling").font(.system(size: 15)).foregroundStyle(Theme.muted); Spacer(); Shimmer().frame(width: 140, height: 16) }.frame(height: 52)
                    Divider().overlay(Theme.line)
                    HStack { Text("Account").font(.system(size: 15)).foregroundStyle(Theme.muted); Spacer(); Text(Fmt.short(app.walletAddress)).font(.system(size: 15, weight: .semibold)) }.frame(height: 52)
                }
                .padding(.top, 28)
                Color.clear.frame(height: 24)
                VStack(alignment: .leading, spacing: 8) { Shimmer().frame(width: 120, height: 22); Shimmer().frame(width: 90, height: 12) }
                if store.phase == .failed { BigButton(label: "Try again", style: side == .sell ? .sell : .buy) { Haptic.medium(); store.error = nil; requote() }.padding(.top, 14) }
                else { BigButton(label: "Getting price…", style: .off) {}.padding(.top, 14) }
            }
            if let q = store.quote {
                VStack(spacing: 0) {
                    row(side == .buy ? "You buy" : "Selling",
                        side == .buy ? "≈ \(store.youGet) · \(Fmt.cash(q.swapUsd ?? q.outUsd))" : Fmt.qty(sellQty, symbol: asset.symbol),
                        .outcome)
                    Divider().overlay(Theme.line)
                    if asset.isStock, let m = q.markUsd { row(asset.isPreIPO ? "Fair value" : "Nasdaq price", Fmt.usd(m), .reference); Divider().overlay(Theme.line) }
                    feesRow(q)
                }
                .padding(.top, 28)
                if let i = q.priceImpactPct, i > 2 { note("Thin market: you're paying \(String(format: "%.1f", i))% above the current price.").padding(.top, 14) }
                if side == .buy, asset.isStock, let p = q.premiumPct, p > 5 { note("Trading \(String(format: "%.0f", p))% above \(asset.isPreIPO ? "its fair value" : "the Nasdaq price").").padding(.top, 14) }
                if let rent = rentUsd(q) {
                    note("First time holding \(asset.symbol): \(Fmt.cash(rent)) is a one-time network fee to open the token in your wallet, added on top. Next time you'd pay just \(Fmt.cash(feesTotal(q) - rent)) on this order.")
                        .padding(.top, 14)
                }
                errorBox.padding(.top, 14)
                Color.clear.frame(height: 24)
                // Footer: total on the left, details underneath, one button.
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(side == .buy ? "\(Fmt.cash(charged(q))) total" : "\(Fmt.cash(q.outUsd)) you get").font(.system(size: 20, weight: .semibold)).tracking(-0.4).monospacedDigit()
                        Text(side == .buy ? "\(Fmt.cash(q.swapUsd ?? q.outUsd)) of \(asset.symbol) + \(Fmt.cash(feesTotal(q))) fees" : "after \(Fmt.cash(feesTotal(q))) fees").font(.sub).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image("usdc").resizable().frame(width: 18, height: 18).clipShape(.circle)
                        Text("USDC · \(Fmt.cash(cash))").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    }
                    .padding(.horizontal, 11).frame(height: 32).background(Theme.surface2, in: .capsule)
                }
                details(q).padding(.top, 10)
                Group {
                    if busy {
                        HStack(spacing: 10) { ProgressView().tint(.white); Text(side == .buy ? "Buying…" : "Selling…").font(.system(size: 17, weight: .semibold)) }
                            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                            .background(side == .sell ? AnyShapeStyle(Theme.sellGradient) : AnyShapeStyle(Theme.buyGradient), in: .capsule)
                    } else if store.phase == .failed {
                        VStack(spacing: 10) {
                            BigButton(label: "Try again", style: side == .sell ? .sell : .buy) {
                                Haptic.medium(); store.error = nil; requote()
                            }
                            if store.slippageFails >= 1, (store.slippageBps ?? 0) < 300 {
                                BigButton(label: "Retry with 3% price move", style: .ghost) {
                                    Haptic.medium(); store.error = nil; store.slippageBps = max(300, store.slippageBps ?? 0); requote()
                                }
                            }
                        }
                    } else if store.phase == .quoting {
                        BigButton(label: "Getting price…", style: .off) {}
                    } else {
                        BigButton(label: side == .buy ? "Buy now" : "Sell now", style: side == .sell ? .sell : .buy) { Haptic.medium(); Task { await run() } }
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    /// Every fee, named: ours, the issuer's (PreStocks only), and Solana's one-time rent.
    private func feesRow(_ q: Quote) -> some View {
        var parts: [String] = ["ApeMe \(String(format: "%g", Double(q.fee?.bps ?? 100) / 100))% \(Fmt.cash(q.fee?.usd ?? 0))"]
        if let f = q.issuerFee, let bps = f.bps, bps > 0 { parts.append("Issuer \(String(format: "%g", Double(bps) / 100))% \(Fmt.cash(f.usd ?? 0))") }
        if let rent = rentUsd(q) { parts.append("\(Fmt.cash(rent)) account setup, one time") }
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Fees").font(.system(size: 15)).foregroundStyle(Theme.muted)
                Spacer()
                Text(Fmt.cash(feesTotal(q))).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(feesAreNotable(q) ? Theme.amber : Theme.ink)
            }
            Text(parts.joined(separator: " · ")).font(.sub).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    private enum RowRank { case normal, outcome, reference }

    private func row(_ k: String, _ v: String, _ rank: RowRank = .normal) -> some View {
        HStack {
            Text(k).font(.system(size: 15)).foregroundStyle(Theme.muted)
            Spacer()
            Text(v)
                .font(.system(size: rank == .outcome ? 16 : 15, weight: rank == .outcome ? .bold : .semibold))
                .foregroundStyle(rank == .reference ? Theme.muted : Theme.ink)
                .monospacedDigit()
        }
        .frame(height: 52)
    }

    /// Amber is for a cost worth pausing on: a one-time account fee, or fees eating more than 5%
    /// of the order. A routine 1% on a $50 buy stays ink — flag everything and amber stops meaning
    /// anything. Applies to a sell the same way.
    private func feesAreNotable(_ q: Quote) -> Bool {
        if rentUsd(q) != nil { return true }
        let total = charged(q)
        guard total > 0 else { return false }
        return feesTotal(q) / total > 0.05
    }

    /// Solana's token-account rent, only when this trade opens the account.
    private func rentUsd(_ q: Quote) -> Double? {
        guard (q.rent?.accounts ?? 0) > 0, let r = q.rent?.usd, r > 0 else { return nil }
        return r
    }

    private func feesTotal(_ q: Quote) -> Double {
        (q.fee?.usd ?? 0) + (q.issuerFee?.usd ?? 0) + ((q.rent?.accounts ?? 0) > 0 ? (q.rent?.usd ?? 0) : 0)
    }

    /// The quote expired and the new price moved more than 1%: show the new numbers, ask once more.
    private var requoted: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            VStack(spacing: 10) {
                assetImage(56)
                Text("Price changed").h1Text()
                Text("Your quote expired and the price moved. Here's the new deal.").font(.sub).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.top, 14)
            if let q = store.replacement {
                KCard {
                    if side == .buy { KV("You pay", Fmt.usd(q.inUsd)) }
                    KV("You get", side == .buy ? "≈ " + youGet(q) : Fmt.usd(q.outUsd))
                }
            }
            Spacer(minLength: 0)
            BigButton(label: side == .buy ? "Pay \(Fmt.usd(store.replacement?.inUsd))" : "Confirm sale", style: side == .sell ? .sell : .buy) {
                guard let w = app.auth.activeWallet else { return }
                Haptic.medium()
                store.takeReplacement()
                app.runTrade(TradeResume(store: store, side: side, asset: asset, amount: amount, pct: pct), wallet: w)
            }
            BigButton(label: "Cancel", style: .ghost) { dismiss() }
        }
    }

    private func youGet(_ q: Quote) -> String {
        if let d = q.outDecimals, let raw = Double(q.outAmount) { return Fmt.qty(raw / pow(10, Double(d)) * (q.multiplier ?? 1), symbol: asset.symbol) }
        return store.youGet
    }

    /// Hands the trade to AppState, which closes this sheet and reports through the toast.
    private func run() async {
        guard let w = app.auth.activeWallet else { store.error = "Sign in first."; return }
        app.runTrade(TradeResume(store: store, side: side, asset: asset, amount: amount, pct: pct), wallet: w)
    }

    // MARK: Done

    private var done: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            VStack(spacing: 14) {
                Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.ground)
                    .frame(width: 56, height: 56).background(Theme.green, in: .circle)
                Text(side == .buy ? "You own \(store.youGet)" : "Sold \(Fmt.qty(sellQty, symbol: asset.symbol))").h1Text().multilineTextAlignment(.center)
                Text("\(side == .buy ? "Paid \(Fmt.usd(store.quote?.inUsd))" : "You got \(store.youGet)") · \(Date.now.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 15)).monospacedDigit().foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity).padding(.top, 14)
            if let q = store.quote { details(q) }
            Spacer(minLength: 16)
            BigButton(label: "Done", style: .white) { dismiss() }
            if let sig = store.signature, let url = URL(string: "https://solscan.io/tx/\(sig)") {
                Link(destination: url) { Text("View on Solscan ↗").font(.sub.weight(.semibold)).foregroundStyle(Theme.muted) }
                    .frame(maxWidth: .infinity)
            }
            #if DEBUG
            Text("req \(store.requestId ?? "—")").font(.system(size: 10)).foregroundStyle(Theme.faint).frame(maxWidth: .infinity).textSelection(.enabled)
            #endif
        }
    }
}
