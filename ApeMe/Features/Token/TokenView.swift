import SwiftUI

/// Coinbase coin page, dark, green. Only reachable in Ape mode or via the bridge.
struct TokenView: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @State private var store: TokenStore

    init(mint: String) { _store = State(initialValue: TokenStore(mint: mint)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BackButton()
                Spacer()
                StatusChip(text: store.status.rawValue, live: store.status == .live)
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

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(t.displaySymbol) price").font(.eyebrow).foregroundStyle(Theme.muted)
                    if isKing { Image(systemName: "crown.fill").font(.system(size: 11)).foregroundStyle(Theme.amber) }
                }
                Text(Fmt.usd(t.priceUsd)).heroText().contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: t.priceUsd)
                HStack(spacing: 4) {
                    Text(Fmt.arrow(t.change24h, 1)).foregroundStyle(Theme.change(t.change24h))
                    Text("today").foregroundStyle(Theme.muted).fontWeight(.medium)
                    Text("·").foregroundStyle(Theme.muted)
                    Text(Fmt.arrow(t.change1h, 1)).foregroundStyle(Theme.change(t.change1h))
                    Text("1h").foregroundStyle(Theme.muted).fontWeight(.medium)
                }
                .font(.system(size: 13, weight: .semibold)).monospacedDigit().padding(.top, 2)
            }
            .padding(.horizontal, 20).padding(.top, 14)

            ohlc.padding(.horizontal, 20).padding(.top, 14)
            chart.padding(.top, 4)
            RangePills(items: TokenRange.allCases, selected: store.range, label: \.rawValue, onSelect: { store.setRange($0) },
                       trailing: AnyView(candleToggle))
                .padding(.top, 10)

            HStack(spacing: 12) {
                statCard("Market cap") { Text(Fmt.big(t.mcapUsd)).h2Text().monospacedDigit() }
                statCard("Floor") {
                    Button { app.push(.floor(t.quoteMint)) } label: { Text("$\(store.stockSymbol)").h2Text() }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.top, 22)

            ActionRow(items: [
                ActionItem(id: "ape", label: app.demoWallet ? "Ape" : "Deposit", symbol: "plus", accent: true) {
                    app.sheet = app.demoWallet ? .apeToken(t.card, t.stock) : .deposit
                },
                ActionItem(id: "sell", label: "Sell", symbol: "minus") { app.show("Nothing to sell yet") },
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

    @ViewBuilder private var ohlc: some View {
        HStack(spacing: 12) {
            if let k = store.scrub {
                let q = store.quoteUsd
                ohlcItem("O", k.o * q); ohlcItem("H", k.h * q); ohlcItem("L", k.l * q); ohlcItem("C", k.c * q)
                Text(Fmt.time(k.t))
            } else if let p = store.scrubPoint {
                Text("\(Text(Fmt.usd(p.price)).foregroundStyle(Theme.ink)) · \(Fmt.dateTime(p.t))")
            }
        }
        .font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.muted)
        .frame(minHeight: 16, alignment: .leading)
    }

    private func ohlcItem(_ l: String, _ v: Double) -> some View {
        Text("\(l) \(Text(Fmt.usd(v)).foregroundStyle(Theme.ink))")
    }

    @ViewBuilder private var chart: some View {
        if store.chartLoading && store.candles.isEmpty {
            Skeleton(height: 200).padding(.horizontal, 20)
        } else if store.showCandles {
            CandleChart(candles: store.candles) { store.scrub = $0 }.padding(.horizontal, 20)
        } else {
            LineChart(points: store.linePoints, tint: store.direction,
                      emptyTitle: "Live from now", emptySubtitle: "The first trade starts the chart.") { p in
                store.scrubPoint = p
                store.scrub = store.range == .live ? nil : p.flatMap { store.candle(at: $0.t) }
            }
            .animation(.easeOut(duration: 0.3), value: store.linePoints.last?.price)
        }
    }

    private var candleToggle: some View {
        Button { store.showCandles.toggle() } label: {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(store.showCandles ? skin.accent : Theme.muted)
                .frame(width: 36, height: 32)
                .background(store.showCandles ? skin.accentTint : .clear, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Candles")
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
            SectionTitle("Recent trades") { StatusChip(text: store.status.rawValue, live: store.status == .live) }
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
