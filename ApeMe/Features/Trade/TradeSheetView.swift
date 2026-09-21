import SwiftUI

/// Buy / Sell / Ape. Real quotes, real signatures. One sheet for stocks and memes.
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
    }

    let side: TradeStore.Side
    let asset: Asset

    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    @State private var store: TradeStore
    @State private var amount = ""            // buy: dollars typed
    @State private var pct: Double? = nil     // sell: chip
    @State private var confirming = false

    init(side: TradeStore.Side, asset: Asset) {
        self.side = side; self.asset = asset
        let holding: Holding? = { if case .holding(let h) = asset { return h }; return nil }()
        _store = State(initialValue: TradeStore(side: side, mint: asset.mint, symbol: asset.symbol, priceUsd: asset.priceUsd, holding: holding,
                                                 priority: Auth.shared.settings.priority ?? "normal"))
    }

    private var verb: String { side == .sell ? "Sell" : asset.isStock ? "Buy" : "Ape" }
    private var usd: Double { Double(amount) ?? 0 }
    private var settings: Me.Settings { app.auth.settings }
    private var quickBuy: [Double] { settings.quickBuyUsd ?? [10, 25, 50, 100] }
    private var quickSell: [Double] { settings.quickSellPct ?? [25, 50, 100] }
    private var busy: Bool { [.signing, .submitting, .confirming].contains(store.phase) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch store.phase {
            case .confirmed: done
            default: if confirming { review } else { form }
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
        .onChange(of: store.priority) { _, _ in requote() }
    }

    private func requote() {
        switch side {
        case .buy: store.requote(usd: usd, taker: app.walletAddress, cashUsd: app.cashUsd)
        case .sell:
            guard let h = store.holding, let raw = h.raw, let r = Decimal(string: raw), let p = pct else { store.requote(rawAmount: nil, taker: app.walletAddress, cashUsd: 0); return }
            var v = r * Decimal(p) / 100
            var out = Decimal(); NSDecimalRound(&out, &v, 0, .down)
            store.requote(rawAmount: "\(out)", taker: app.walletAddress, cashUsd: 0)
        }
    }

    // MARK: Form

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                if asset.isStock { Logo(url: asset.imageURL, symbol: asset.symbol, size: 28) } else { Avatar(url: asset.imageURL, symbol: asset.symbol, size: 28) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(verb) \(asset.symbol)").h3Text()
                    Text(side == .sell ? "You hold \(Fmt.qty(store.holding?.amount ?? 0, symbol: asset.symbol)) · \(Fmt.usd(store.holding?.valueUsd))" : "Cash \(Fmt.usd(app.cashUsd))")
                        .font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(busy)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if side == .buy {
                VStack(spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("$").font(.system(size: 40, weight: .medium)).foregroundStyle(Theme.faint)
                        Text(amount.isEmpty ? "0" : amount).font(.amount).tracking(-2.8).monospacedDigit().foregroundStyle(Theme.ink)
                    }
                    Text("You get ≈ \(store.phase == .quoting ? "…" : store.youGet)").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity).padding(.top, 8)
                chips(quickBuy.map { ("$" + Fmt.n($0), $0) }, selected: usd) { amount = Fmt.n($0) }
            } else {
                VStack(spacing: 4) {
                    Text(pct.map { Fmt.n($0) + "%" } ?? "—").font(.amount).tracking(-2.8).monospacedDigit().foregroundStyle(Theme.ink)
                    Text("You get ≈ \(store.phase == .quoting ? "…" : store.youGet)").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity).padding(.top, 8)
                chips(quickSell.map { (Fmt.n($0) + "%", $0) }, selected: pct ?? -1) { pct = $0 }
            }
            details
            if side == .buy { Numpad { key in
                switch key {
                case "⌫": amount = String(amount.dropLast())
                case ".": if !amount.contains(".") { amount = (amount.isEmpty ? "0" : amount) + "." }
                default:
                    let d = amount.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
                    if amount.count < 8, !amount.contains(".") || d < 2 { amount = amount == "0" ? key : amount + key }
                }
            } }
            if let e = store.error, store.phase == .failed {
                Text(e).font(.sub).foregroundStyle(Theme.red).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 12).background(Theme.redT, in: .rect(cornerRadius: 12))
            }
            Spacer(minLength: 0)
            primary
        }
    }

    private func chips(_ items: [(String, Double)], selected: Double, pick: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.1) { label, v in
                let on = v == selected
                Button { pick(v) } label: {
                    Text(label).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(on ? skin.accent : Theme.ink)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(on ? skin.accentTint : Theme.surface2, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var details: some View {
        let q = store.quote
        VStack(alignment: .leading, spacing: 8) {
            if asset.isStock, let mark = q?.markUsd {
                HStack(spacing: 4) {
                    Text("\(asset.isPreIPO ? "Fair value" : "Nasdaq") \(Fmt.usd(mark))").foregroundStyle(Theme.muted)
                    Text("·").foregroundStyle(Theme.faint)
                    Text("here \(Fmt.pct(q?.premiumPct, 2))").foregroundStyle(Theme.ink)
                }
                .font(.sub).monospacedDigit()
            }
            HStack(spacing: 4) {
                Text("Fee \(Fmt.usd(q?.fee?.usd ?? 0)) · Gas free").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                Spacer()
                priorityChip
            }
            if let rent = q?.rent?.usd, rent > 0 {
                Text("One-time network fee \(Fmt.usd(rent)) to hold \(asset.symbol)").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
            }
            if let p = q?.premiumPct, p > 5, side == .buy {
                Text("You're paying \(String(format: "%.1f", p))% over the \(asset.isPreIPO ? "fair value" : "Nasdaq price").")
                    .font(.sub).foregroundStyle(Theme.amber).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 10).background(Theme.amberT, in: .rect(cornerRadius: 10))
            }
        }
    }

    private var priorityChip: some View {
        Menu {
            ForEach(["normal", "fast", "turbo"], id: \.self) { p in
                if p != "turbo" || usd >= 50 || side == .sell {
                    Button { store.priority = p } label: { Label(p.capitalized, systemImage: store.priority == p ? "checkmark" : "") }
                }
            }
        } label: {
            HStack(spacing: 4) { Image(systemName: "bolt.fill").font(.system(size: 11)); Text(store.priority.capitalized) }
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(height: 28).background(Theme.surface2, in: .capsule)
        }
    }

    @ViewBuilder private var primary: some View {
        switch store.phase {
        case .insufficient:
            BigButton(label: "Deposit to buy", style: .white) { dismiss(); app.sheet = .deposit }
        case .quoting:
            BigButton(label: "Getting quote…", style: .off) {}
        case .ready:
            let label = side == .buy ? "\(verb) $\(amount) of \(asset.symbol)" : "Sell \(Fmt.n(pct ?? 0))% of \(asset.symbol)"
            BigButton(label: label, style: side == .sell ? .sell : .buy) {
                if settings.confirmBeforeTrade ?? true { confirming = true } else { Task { await run() } }
            }
        case .signing: BigButton(label: "Signing…", style: .off) {}
        case .submitting: BigButton(label: "Submitting…", style: .off) {}
        case .confirming: BigButton(label: "Confirming…", style: .off) {}
        case .failed:
            BigButton(label: "Try again", style: .ghost) { requote() }
        default:
            BigButton(label: side == .buy ? "Enter an amount" : "Pick an amount", style: .off) {}
        }
    }

    // MARK: Review / done

    private var review: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back") { confirming = false }.disabled(busy)
                Spacer(); Text("Review").h3Text(); Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }.disabled(busy)
            }
            Text(side == .buy ? "\(verb) $\(amount) of \(asset.symbol)" : "Sell \(Fmt.n(pct ?? 0))% of \(asset.symbol)").h1Text().padding(.top, 6)
            KCard {
                KV("You pay", side == .buy ? Fmt.usd(store.quote?.inUsd) : Fmt.qty(store.holding.map { $0.amount * (pct ?? 0) / 100 } ?? 0, symbol: asset.symbol))
                KV("You get", "≈ " + store.youGet)
                if asset.isStock, let m = store.quote?.markUsd { KV(asset.isPreIPO ? "Fair value" : "Nasdaq", Fmt.usd(m)) }
                KV("Fee", Fmt.usd(store.quote?.fee?.usd ?? 0))
                if let rent = store.quote?.rent?.usd, rent > 0 { KV("One-time network fee", Fmt.usd(rent)) }
                if side == .buy, let t = store.quote?.totalChargeUsd, t > 0 { KV("Total from cash", Fmt.usd((store.quote?.inUsd ?? 0) + t)) }
                KV("Gas", "Free · ApeMe pays")
                KV("Slippage", "\(Double(store.quote?.slippageBps ?? 100) / 100)%")
                KV("Account", Fmt.short(app.walletAddress))
            }
            if let e = store.error, store.phase == .failed {
                Text(e).font(.sub).foregroundStyle(Theme.red).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 12).background(Theme.redT, in: .rect(cornerRadius: 12))
            }
            Spacer(minLength: 0)
            switch store.phase {
            case .signing: BigButton(label: "Signing…", style: .off) {}
            case .submitting: BigButton(label: "Submitting…", style: .off) {}
            case .confirming: HStack { ProgressView().tint(Theme.ink); Text("Confirming on Solana…").font(.system(size: 15, weight: .semibold)) }.frame(maxWidth: .infinity).frame(height: 52)
            case .failed: BigButton(label: "Try again", style: .ghost) { confirming = false; requote() }
            default: BigButton(label: "Confirm", style: side == .sell ? .sell : .buy) { Task { await run() } }
            }
        }
    }

    private func run() async {
        guard let w = app.auth.activeWallet, let taker = app.walletAddress else { store.error = "Sign in first."; return }
        await store.execute(wallet: w, taker: taker, cashUsd: app.cashUsd) {
            Task { await app.loadWallet(fresh: true) }
        }
    }

    private var done: some View {
        VStack(spacing: 16) {
            HStack { Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            VStack(spacing: 16) {
                Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.ground)
                    .frame(width: 56, height: 56).background(Theme.green, in: .circle)
                Text(side == .buy ? "You own \(store.youGet)" : "Sold for \(store.youGet)").h1Text().multilineTextAlignment(.center)
                if let sig = store.signature {
                    Link(destination: URL(string: "https://solscan.io/tx/\(sig)")!) {
                        Text("View on Solscan ↗").font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                }
                #if DEBUG
                Text("req \(store.requestId ?? "—")\n\(store.signature ?? "")").font(.system(size: 10)).foregroundStyle(Theme.faint).multilineTextAlignment(.center).textSelection(.enabled)
                #endif
            }
            .padding(.vertical, 12)
            BigButton(label: "Done", style: .white) { dismiss() }
        }
    }
}
