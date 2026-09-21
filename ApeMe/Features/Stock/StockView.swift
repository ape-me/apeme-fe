import SwiftUI

struct StockView: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @State private var store: StockStore
    @State private var compact = false

    init(mint: String) { _store = State(initialValue: StockStore(mint: mint)) }

    var body: some View {
        VStack(spacing: 0) {
            topbar
            ScrollView {
                Group {
                    if let s = store.stock { content(s) }
                    else if let err = store.error { ErrorBar(text: err) }
                    else { VStack(spacing: 10) { Skeleton(); Skeleton(height: 44); Skeleton(height: 200) }.padding(20) }
                }
                .reportScrollOffset(in: "stock")
            }
            .coordinateSpace(name: "stock")
            .scrollIndicators(.hidden)
            .onPreferenceChange(ScrollOffsetKey.self) { y in
                let v = y > 120
                if v != compact { withAnimation(.easeOut(duration: 0.15)) { compact = v } }
            }
        }
        .background(Theme.ground)
        .task { await store.load(app: app) }
        .task { await store.poll(app: app) }
    }

    private var topbar: some View {
        ZStack {
            HStack(spacing: 10) {
                BackButton()
                Spacer()
                Pill(label: app.isWatching(store.mint) ? "Watching" : "Watch",
                     icon: app.isWatching(store.mint) ? "star.fill" : "star") { app.toggleWatch(store.mint) }
                IconButton(symbol: "square.and.arrow.up", label: "Share") { app.copy(store.mint) }
            }
            .opacity(compact ? 0 : 1)
            if compact, let s = store.stock {
                HStack {
                    BackButton()
                    Spacer()
                    VStack(spacing: 0) {
                        Text(s.symbol).font(.system(size: 14, weight: .semibold))
                        Text("\(Text(Fmt.arrow(s.change24h)).foregroundStyle(Theme.change(s.change24h))) today")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .background(Theme.ground)
            }
        }
        .padding(.horizontal, 12).padding(.top, 6)
        .frame(minHeight: 56)
    }

    private func content(_ s: Stock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            hero(s)
            chart(s).padding(.top, 20)
            RangePills(items: HistoryRange.allCases, selected: store.range, label: \.label) { store.setRange($0) }
                .padding(.top, 14)
            HStack(spacing: 10) {
                BigButton(label: "Buy", style: .primary) { app.sheet = .buyStock(s) }
                BigButton(label: "Sell", style: .ghost) { app.show("Nothing to sell yet") }
            }
            .padding(.horizontal, 20).padding(.top, 18)
            HR().padding(.top, 26)
            if let mark = s.markUsd, let p = s.premiumPct { fairValue(s, mark, p) }
            stats(s)
            HStack(spacing: 6) {
                StatusChip(text: app.online ? "Live" : "Snapshot", live: app.online)
            }
            .padding(.horizontal, 20).padding(.top, 20)
        }
        .padding(.bottom, 24)
    }

    private func hero(_ s: Stock) -> some View {
        let scrubbing = store.scrub != nil
        let price = store.scrub?.price ?? s.priceUsd
        let change = scrubbing ? store.scrubChange : s.change24h
        let abs: Double? = zip2(s.change24h, s.priceUsd).map { ch, p in p - p / (1 + ch / 100) }
        return VStack(alignment: .leading, spacing: 6) {
            Text(s.name).font(.system(size: 18, weight: .medium)).tracking(-0.45)
            Text(Fmt.usd(price)).heroText().contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: price)
            HStack(spacing: 4) {
                Text(Fmt.arrow(change)).foregroundStyle(Theme.change(change))
                if let sp = store.scrub {
                    Text(Fmt.dateTime(sp.t) + (sp.mark.map { " · fair \(Fmt.usd($0))" } ?? "")).foregroundStyle(Theme.muted).fontWeight(.medium)
                } else {
                    if let abs { Text((abs >= 0 ? "+" : "−") + "$" + String(format: "%.2f", Swift.abs(abs)) + " ·").foregroundStyle(Theme.muted).fontWeight(.medium) }
                    Text(store.range.caption).foregroundStyle(Theme.muted).fontWeight(.medium)
                }
            }
            .font(.system(size: 13, weight: .semibold)).monospacedDigit()
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    @ViewBuilder private func chart(_ s: Stock) -> some View {
        if store.chartLoading && store.points.isEmpty {
            Skeleton(height: 200).padding(.horizontal, 20)
        } else {
            LineChart(points: store.points) { store.scrub = $0 }
                .animation(.easeOut(duration: 0.3), value: store.points.last?.price)
        }
    }

    private func fairValue(_ s: Stock, _ mark: Double, _ p: Double) -> some View {
        let w = min(96, max(8, abs(p) * 4))
        return VStack(alignment: .leading, spacing: 14) {
            Text("Fair value").h2Text()
            VStack(spacing: 10) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surface2)
                        Capsule().fill(Theme.amberT).frame(width: g.size.width * min(100, max(8, abs(p) * 4)) / 100)
                        Circle().fill(Theme.amber).frame(width: 12, height: 12).overlay(Circle().stroke(Theme.ground, lineWidth: 2))
                        Circle().fill(skin.accent).frame(width: 12, height: 12).overlay(Circle().stroke(Theme.ground, lineWidth: 2))
                            .offset(x: g.size.width * w / 100)
                    }
                }
                .frame(height: 6)
                HStack {
                    Text("\(Fmt.usd(mark)) fair").foregroundStyle(Theme.amber)
                    Spacer()
                    PremiumBadge(pct: p)
                    Spacer()
                    Text("\(Fmt.usd(s.priceUsd)) now")
                }
                .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text(s.isPreIPO
                     ? "PreStocks publishes a fair value from the company's last round. The token trades above or below it; the gap is the premium."
                     : "Fair value is the real exchange price. The token tracks it closely.")
                .font(.sub).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 20).padding(.top, 22)
    }

    private func stats(_ s: Stock) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Market stats")
                KCard {
                    KV("Fair value", Fmt.usd(s.markUsd))
                    KV("Liquidity", Fmt.big(s.liquidityUsd))
                    KV("24h volume", Fmt.big(s.stockVol24hUsd))
                    KV("Buys · sells") {
                        Text("\(Text(Fmt.n(s.buys24h)).foregroundStyle(Theme.green)) \(Text("/").foregroundStyle(Theme.faint)) \(Text(Fmt.n(s.sells24h)).foregroundStyle(Theme.red))")
                    }
                    KV("Market") {
                        HStack(spacing: 6) {
                            Circle().fill(s.marketOpen ? Theme.green : Theme.faint).frame(width: 6, height: 6)
                            Text(s.marketOpen ? "Open" : "After hours · trades 24/7 here")
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Buys vs sells · 24h")
                KCard(padded: true) { SplitBar(a: s.buys24h, b: s.sells24h) }
            }
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("About")
                KCard {
                    KV("Issuer", s.issuer)
                    KV("Category", s.category)
                    KV("Mint address") { CopyButton(text: Fmt.short(s.mint), value: s.mint) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 22)
    }
}

struct CopyButton: View {
    let text: String
    let value: String
    @Environment(AppState.self) private var app
    var body: some View {
        Button { app.copy(value) } label: {
            HStack(spacing: 6) {
                Text(text)
                Image(systemName: "doc.on.doc").font(.system(size: 12))
            }
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
    }
}


private func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
