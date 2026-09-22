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

    init(side: TradeStore.Side, asset: Asset) {
        self.side = side; self.asset = asset
        let holding: Holding? = { if case .holding(let h) = asset { return h }; return nil }()
        _store = State(initialValue: TradeStore(side: side, mint: asset.mint, symbol: asset.symbol, priceUsd: asset.priceUsd, holding: holding,
                                                 priority: Auth.shared.settings.priority ?? "normal"))
    }

    private var verb: String { side == .sell ? "Sell" : asset.isStock ? "Buy" : "Ape" }
    private var usd: Double { Double(amount) ?? 0 }
    private var settings: Me.Settings { app.auth.settings }
    private var cash: Double { app.cashUsd }
    private var maxCash: Double { floor(cash * 100) / 100 }
    private var busy: Bool { [.signing, .submitting, .confirming].contains(store.phase) }
    private var sellValue: Double { store.holding?.valueUsd ?? 0 }
    private var sellQty: Double { sellValue > 0 ? (store.holding?.amount ?? 0) * min(usd, sellValue) / sellValue : 0 }
    private var hasAmount: Bool { usd > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch store.phase {
            case .confirmed: ScrollView { done }.scrollIndicators(.hidden)
            case .requoted: requoted
            default: if reviewing { review } else { form }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(busy)
        .task { if app.wallet == nil { await app.loadWallet() } }
        .onChange(of: amount) { _, _ in requote() }
        .onChange(of: pct) { _, _ in requote() }
        .onChange(of: scenePhase) { _, p in if p == .active { Task { await store.refresh() } } }
    }

    private func requote() {
        switch side {
        case .buy: store.requote(usd: usd, taker: app.walletAddress, cashUsd: cash)
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
        HStack {
            HStack(spacing: 10) {
                assetImage(28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(verb) \(asset.symbol)").h3Text()
                    Text(side == .sell ? "You hold \(Fmt.qty(store.holding?.amount ?? 0, symbol: asset.symbol)) · \(Fmt.usd(store.holding?.valueUsd))" : "Cash \(Fmt.usd(cash))")
                        .font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(busy)
        }
    }

    @ViewBuilder private func assetImage(_ size: CGFloat) -> some View {
        if asset.isStock { Logo(url: asset.imageURL, symbol: asset.symbol, size: size) } else { Avatar(url: asset.imageURL, symbol: asset.symbol, size: size) }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 12)
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image("usdc").resizable().frame(width: 36, height: 36).clipShape(.circle)
                    Text(amount.isEmpty ? "0" : amount).font(.amount).tracking(-2.8).monospacedDigit().foregroundStyle(Theme.ink)
                }
                HStack(spacing: 4) {
                    if side == .buy {
                        Text("You get ≈").foregroundStyle(Theme.muted)
                        Text(store.phase == .quoting ? "…" : store.youGet).foregroundStyle(Theme.ink).fontWeight(.semibold)
                    } else {
                        Text("≈ \(Fmt.qty(sellQty, symbol: asset.symbol))").foregroundStyle(Theme.ink).fontWeight(.semibold)
                        if sellValue > 0 { Text("· \(Fmt.n(min(100, usd / sellValue * 100).rounded()))%").foregroundStyle(Theme.muted) }
                    }
                }
                .font(.system(size: 15)).monospacedDigit()
                .opacity(hasAmount ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 12)
            if side == .buy {
                chips((settings.quickBuyUsd ?? [10, 25, 50, 100]).map { ("$" + Fmt.n($0), nil, $0) } + [("Max", nil, maxCash)], selected: usd) { amount = String(format: $0 == maxCash ? "%.2f" : "%g", $0); pct = nil }
            } else {
                chips((settings.quickSellPct ?? [25, 50, 100]).map { p in (Fmt.n(p) + "%", Fmt.usd(sellValue * p / 100), sellValue * p / 100) }, selected: usd) { v in
                    amount = String(format: "%.2f", floor(v * 100) / 100); pct = abs(v - sellValue) < 0.005 ? 100 : nil
                }
            }
            notes.padding(.top, 12)
            Spacer(minLength: 12)
            Numpad { key in
                pct = nil
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
                let on = abs(v - selected) < 0.006
                Button { pick(v) } label: {
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
                note("Large order: price impact \(String(format: "%.1f", i))%. You get less per dollar.")
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.sub).foregroundStyle(Theme.amber).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10).background(Theme.amberT, in: .rect(cornerRadius: 10))
    }

    @ViewBuilder private var errorBox: some View {
        if let e = store.error, store.phase == .failed {
            VStack(alignment: .leading, spacing: 4) {
                Text(e).font(.sub).foregroundStyle(Theme.red)
                #if DEBUG
                if let r = store.requestId { Text("req \(r)").font(.system(size: 10)).foregroundStyle(Theme.faint).textSelection(.enabled) }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12).background(Theme.redT, in: .rect(cornerRadius: 12))
        }
    }

    @ViewBuilder private var primary: some View {
        switch store.phase {
        case .insufficient:
            if side == .buy { BigButton(label: "Deposit to buy", style: .white) { dismiss(); app.sheet = .deposit } }
            else { BigButton(label: "You hold \(Fmt.cash(sellValue)) · Sell all", style: .white) { amount = String(format: "%.2f", floor(sellValue * 100) / 100); pct = 100 } }
        case .quoting: BigButton(label: "Getting price…", style: .off) {}
        case .ready:
            BigButton(label: "Review order", style: side == .sell ? .sell : .buy) { reviewing = true }
        case .signing: BigButton(label: "Signing…", style: .off) {}
        case .submitting: BigButton(label: "Submitting…", style: .off) {}
        case .confirming: BigButton(label: "Confirming…", style: .off) {}
        case .failed: BigButton(label: "Try again", style: .ghost) { requote() }
        default: BigButton(label: "Enter an amount", style: .off) {}
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
                    if (q.rent?.accounts ?? 0) > 0 { KV("One-time network fee", Fmt.cash(q.rent?.usd ?? 0)) }
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
            if let q = store.quote {
                VStack(spacing: 0) {
                    row("Receive", side == .buy ? "≈ " + store.youGet : Fmt.qty(sellQty, symbol: asset.symbol))
                    Divider().overlay(Theme.line)
                    if asset.isStock, let m = q.markUsd { row(asset.isPreIPO ? "Fair value" : "Nasdaq price", Fmt.usd(m)); Divider().overlay(Theme.line) }
                    row("Account", Fmt.short(app.walletAddress))
                }
                .padding(.top, 28)
                if let i = q.priceImpactPct, i > 2 { note("Large order: price impact \(String(format: "%.1f", i))%. You get less per dollar.").padding(.top, 14) }
                if side == .buy, asset.isStock, let p = q.premiumPct, p > 5 { note("Trading \(String(format: "%.0f", p))% above \(asset.isPreIPO ? "its fair value" : "the Nasdaq price").").padding(.top, 14) }
                errorBox.padding(.top, 14)
                Spacer(minLength: 20)
                // Footer: total on the left, details underneath, one button.
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(side == .buy ? "\(Fmt.cash(q.inUsd)) total" : "\(Fmt.cash(q.outUsd)) you get").font(.system(size: 20, weight: .semibold)).tracking(-0.4).monospacedDigit()
                        Text("incl. \(Fmt.cash(feesTotal(q))) fees").font(.sub).foregroundStyle(Theme.muted)
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
                                guard let w = app.auth.activeWallet else { return }
                                Task { await store.retry(wallet: w) { app.settleWallet() } }
                            }
                            if store.slippageFails >= 1, (store.slippageBps ?? 0) < 300 {
                                BigButton(label: "Retry with 3% price move", style: .ghost) {
                                    guard let w = app.auth.activeWallet else { return }
                                    Task { await store.retryWider(wallet: w) { app.settleWallet() } }
                                }
                            }
                        }
                    } else if store.phase == .quoting {
                        BigButton(label: "Getting price…", style: .off) {}
                    } else {
                        BigButton(label: side == .buy ? "Buy now" : "Sell now", style: side == .sell ? .sell : .buy) { Task { await run() } }
                    }
                }
                .padding(.top, 14)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.system(size: 15)).foregroundStyle(Theme.muted); Spacer(); Text(v).font(.system(size: 15, weight: .semibold)).monospacedDigit() }
            .frame(height: 52)
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
                Task { await store.acceptReplacement(wallet: w) { app.settleWallet() } }
            }
            BigButton(label: "Cancel", style: .ghost) { dismiss() }
        }
    }

    private func youGet(_ q: Quote) -> String {
        if let d = q.outDecimals, let raw = Double(q.outAmount) { return Fmt.qty(raw / pow(10, Double(d)) * (q.multiplier ?? 1), symbol: asset.symbol) }
        return store.youGet
    }

    private func run() async {
        guard let w = app.auth.activeWallet else { store.error = "Sign in first."; return }
        await store.execute(wallet: w) { app.settleWallet() }
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
