import SwiftUI

/// Coinbase coin page, dark, green. Only reachable in Ape mode or via the bridge.
struct TokenView: View {
    @Environment(AppState.self) private var app
    @State private var store: TokenStore
    @State private var showMcap = false

    init(mint: String) { _store = State(initialValue: TokenStore(mint: mint)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BackButton()
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 6).frame(minHeight: 56)
            ScrollView {
                if let t = store.token { content(t) }
                else if let err = store.error { ErrorBar(text: err) }
                else { VStack(spacing: 16) { Skeleton(height: 44); Skeleton(height: 200) }.padding(20) }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .environment(\.skin, Skin(mode: .ape))
        .task {
            store.connect()
            await store.load(app: app)
        }
        .onDisappear { store.disconnect() }
    }

    private func content(_ t: TokenHeader) -> some View {
        let isKing = app.stocksByMint[t.quoteMint]?.king?.mint == t.mint
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Avatar(url: t.imageURL, symbol: t.displaySymbol, size: 28)
                Spacer()
                Pill(label: app.isWatchingToken(t.mint) ? "Watching" : "Watch",
                     icon: app.isWatchingToken(t.mint) ? "star.fill" : "star") { app.toggleTokenWatch(t.mint) }
            }
            .padding(.horizontal, 20).padding(.top, 4)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(t.displaySymbol) \(showMcap ? "market cap" : "price")").font(.eyebrow).foregroundStyle(Theme.muted)
                        if isKing { Image(systemName: "crown.fill").font(.system(size: 11)).foregroundStyle(Theme.amber) }
                    }
                    Text(showMcap ? Fmt.big(t.mcapUsd) : Fmt.usd(store.priceUsd)).heroText().contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.3), value: store.priceUsd)
                    rangeChange
                }
                Spacer(minLength: 8)
                Button { withAnimation(.easeOut(duration: 0.2)) { showMcap.toggle() } } label: {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
                            Text(showMcap ? Fmt.usd(store.priceUsd) : Fmt.big(t.mcapUsd)).h2Text().monospacedDigit()
                        }
                        Text(showMcap ? "Price" : "Market cap").font(.sub).foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showMcap ? "Show price" : "Show market cap")
            }
            .padding(.horizontal, 20).padding(.top, 14)

            ohlc.padding(.horizontal, 20).padding(.top, 14)
            chart.padding(.top, 4)
            RangePills(items: TokenRange.allCases, selected: store.range, label: \.rawValue) { store.setRange($0) }
                .padding(.top, 10)

            statCard("Floor") {
                HStack {
                    Button { app.push(.floor(t.quoteMint)) } label: { Text("$\(store.stockSymbol)").h2Text() }.buttonStyle(.plain)
                    Spacer()
                    Text("\(Fmt.usd(t.stock.priceUsd)) · \(Fmt.arrow(t.stock.change24h))").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 20).padding(.top, 22)

            ActionRow(items: [
                ActionItem(id: "ape", label: app.hasWallet ? "Ape" : "Deposit", symbol: "plus", tone: Theme.buy) {
                    app.sheet = app.hasWallet ? .apeToken(t.card, t.stock) : .deposit
                },
                ActionItem(id: "sell", label: "Sell", symbol: "minus", tone: Theme.sell) { app.show("Nothing to sell yet") },
                ActionItem(id: "floor", label: "Floor", symbol: "arrow.left.arrow.right") { app.push(.floor(t.quoteMint)) },
                ActionItem(id: "share", label: "Share", symbol: "square.and.arrow.up") { app.copy(t.mint) },
            ])
            .padding(.horizontal, 20).padding(.top, 20)

            HR().padding(.top, 24)
            UnderlineTabs(items: TokenStore.Tab.allCases, selected: store.tab, fill: true, label: \.label) { store.tab = $0 }
                .padding(.horizontal, 20).padding(.top, 4)

            switch store.tab {
            case .trades: TradesTab(store: store, token: t)
            case .holders: HoldersTab(token: t)
            case .about: AboutTab(store: store, token: t)
            }
        }
        .padding(.bottom, 24)
    }

    /// Change over what's on the chart: first point → now, absolute and percent.
    @ViewBuilder private var rangeChange: some View {
        let pts = store.linePoints
        if let f = pts.first, let l = pts.last, f.price > 0 {
            let abs = l.price - f.price, pct = abs / f.price * 100
            let up = abs >= 0
            HStack(spacing: 4) {
                Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 9))
                Text("\(Fmt.usd(Swift.abs(abs))) (\(String(format: "%.2f", Swift.abs(pct)))%)")
                Text(store.range == .live ? "live" : store.range.rawValue.lowercased()).foregroundStyle(Theme.muted).fontWeight(.medium)
            }
            .font(.system(size: 13, weight: .semibold)).monospacedDigit()
            .foregroundStyle(up ? Theme.green : Theme.red)
            .padding(.top, 2)
        } else {
            HStack(spacing: 4) {
                Text(Fmt.arrow(t24, 1)).foregroundStyle(Theme.change(t24))
                Text("today").foregroundStyle(Theme.muted).fontWeight(.medium)
            }
            .font(.system(size: 13, weight: .semibold)).monospacedDigit().padding(.top, 2)
        }
    }
    private var t24: Double? { store.token?.change24h }

    /// Scrub readout: price · time of the point under the finger.
    @ViewBuilder private var ohlc: some View {
        HStack {
            if let p = store.scrubPoint {
                Text("\(Text(Fmt.usd(p.price)).foregroundStyle(Theme.ink)) · \(Fmt.dateTime(p.t))")
            }
        }
        .font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.muted)
        .frame(minHeight: 16, alignment: .leading)
    }

    @ViewBuilder private var chart: some View {
        if store.chartLoading && store.linePoints.isEmpty {
            Skeleton(height: 260).padding(.horizontal, 20)
        } else {
            LineChart(points: store.linePoints, tint: store.direction, live: true, height: 260,
                      emptyTitle: "Live from now", emptySubtitle: "The first trade starts the chart.") { store.scrubPoint = $0 }
            .animation(.easeOut(duration: 0.3), value: store.linePoints.last?.price)
        }
    }

    private func statCard(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.eyebrow).foregroundStyle(Theme.muted)
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
    }
}

struct TradesTab: View {
    @Bindable var store: TokenStore
    let token: TokenHeader

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Recent trades")
            VStack(spacing: 0) {
                if store.tradesLoading && store.trades.isEmpty {
                    Skeleton(height: 60).padding(12)
                } else if store.trades.isEmpty {
                    EmptyState(title: "No trades yet")
                } else {
                    let last = store.trades.last?.sig
                    ForEach(store.trades) { t in
                        TradeRow(trade: t, symbol: token.displaySymbol, flash: store.tapeFlash[t.sig])
                        if t.sig != last { Divider().overlay(Theme.line) }
                    }
                }
            }
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .animation(.easeOut(duration: 0.25), value: store.trades.first?.sig)
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }
}

struct TradeRow: View {
    let trade: Trade
    let symbol: String
    let flash: Flash?

    var body: some View {
        let buy = trade.side == .buy
        HStack(spacing: 12) {
            Text(buy ? "B" : "S")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(buy ? Theme.green : Theme.red)
                .frame(width: 36, height: 36)
                .background(buy ? Theme.greenT : Theme.redT, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(buy ? "Bought" : "Sold") \(Fmt.big(trade.base, "")) \(symbol)").font(.rowTitle).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text("\(Fmt.short(trade.wallet)) · \(Fmt.ago(trade.ts, now: ctx.date)) ago").font(.sub).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.big(trade.priceUsd.map { $0 * trade.base })).font(.rowTitle).monospacedDigit()
                Text(Fmt.usd(trade.priceUsd)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 6).frame(minHeight: 60)
        .background { FlashBackground(flash: flash) }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct HoldersTab: View {
    let token: TokenHeader

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Holders")
                KCard {
                    KV("Holders", Fmt.n(token.holders))
                    KV("Top 10 hold") { pct(token.top10Pct, red: { $0 > 20 }) }
                    KV("Dev holds") { pct(token.devPct, red: { $0 > 20 }, green: { $0 < 5 }) }
                    KV("Snipers") { pct(token.snipersPct, red: { $0 > 10 }) }
                    KV("Transfer tax", String(format: "%.1f%%", Double(token.taxBps ?? 0) / 100))
                    KV("DexScreener") { Text(token.dexPaid == true ? "Paid" : "Not paid").foregroundStyle(token.dexPaid == true ? Theme.green : Theme.ink) }
                }
                if token.holders == nil {
                    Text("Holder breakdown is exact for tokens indexed since launch. This one predates the index.")
                        .font(.sub).foregroundStyle(Theme.muted).padding(.top, 10)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("What to watch")
                KCard {
                    KV("Top 10 over 20%") { Text("Concentrated").foregroundStyle(Theme.red) }
                    KV("Dev under 5%") { Text("Healthy").foregroundStyle(Theme.green) }
                    KV("Snipers over 10%") { Text("Risky").foregroundStyle(Theme.red) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    private func pct(_ v: Double?, red: (Double) -> Bool, green: (Double) -> Bool = { _ in false }) -> Text {
        guard let v else { return Text("—") }
        let color: Color = red(v) ? Theme.red : green(v) ? Theme.green : Theme.ink
        return Text(String(format: "%.1f%%", v)).foregroundStyle(color)
    }
}

struct AboutTab: View {
    @Bindable var store: TokenStore
    let token: TokenHeader
    @Environment(AppState.self) private var app

    var body: some View {
        let t = token
        let (b, s, v): (Int?, Int?, Double?) = switch store.window {
            case .m5: (t.buys5m, t.sells5m, t.vol5mUsd)
            case .h1: (t.buys1h, t.sells1h, t.vol1hUsd)
            case .h24: (t.buys24h, t.sells24h, t.vol24hUsd)
        }
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("About \(t.displaySymbol)")
                KCard(padded: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(t.displayName) is a community token launched on the \(Text(store.stockSymbol).fontWeight(.semibold)) floor via \(t.launchpad). \(t.phase == .graduated ? "It has graduated to an open market." : "It is \(Int((t.progressPct ?? 0).rounded()))% of the way to graduating.")")
                            .font(.body15).lineSpacing(3)
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 11))
                            Text("Unverified. Anyone can launch a token; it can lose all value.")
                        }
                        .font(.sub).foregroundStyle(Theme.muted)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Transactions") {
                    HStack(spacing: 4) {
                        ForEach(TokenStore.Window.allCases) { w in
                            Pill(label: w.rawValue, on: store.window == w, size: .xsmall) { store.window = w }
                        }
                    }
                }
                KCard(padded: true) {
                    VStack(spacing: 14) {
                        SplitBar(a: b, b: s)
                        HStack {
                            Text("\(Text(Fmt.big(v)).fontWeight(.semibold).foregroundStyle(Theme.ink)) volume")
                            Spacer()
                            Text("\(Text(Fmt.n((b ?? 0) + (s ?? 0))).fontWeight(.semibold).foregroundStyle(Theme.ink)) trades")
                        }
                        .font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Market stats")
                KCard {
                    KV("Market cap", Fmt.big(t.mcapUsd))
                    KV("All-time high", Fmt.big(t.athMcapUsd))
                    KV("24h volume", Fmt.big(t.vol24hUsd))
                    KV("Price in \(store.stockSymbol)", t.priceQuote.map { String(Fmt.usd($0 * (t.stock.multiplier ?? 1)).dropFirst()) } ?? "—")
                    KV("Supply", Fmt.supply(t.supply, t.decimals))
                    KV("Created", Fmt.ago(t.createdAt) + " ago")
                    KV("Launchpad", t.launchpad)
                    KV("Phase", t.phase.rawValue + (t.phase != .graduated ? " · \(Int((t.progressPct ?? 0).rounded()))%" : ""))
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Resources")
                KCard {
                    KV("Floor") {
                        Button { app.push(.floor(t.quoteMint)) } label: { Text("$\(store.stockSymbol) ↗") }.buttonStyle(.plain)
                    }
                    KV("Mint address") { CopyButton(text: Fmt.short(t.mint), value: t.mint) }
                    if let w = t.website, let u = URL(string: w) { KV("Website") { Link("Open ↗", destination: u) } }
                    if let x = t.twitter, let u = URL(string: x) { KV("X") { Link("Open ↗", destination: u) } }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }
}
