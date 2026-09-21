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
        .task {
            store.connect(app: app)
            await store.load(app: app)
        }
        .task { await store.resync() }
        .onDisappear { store.disconnect() }
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
            ranges.padding(.top, 14)
            HStack(spacing: 10) {
                BigButton(label: "Buy", style: .primary) { app.sheet = .buyStock(s) }
                BigButton(label: "Sell", style: .ghost) { app.show("Nothing to sell yet") }
            }
            .padding(.horizontal, 20).padding(.top, 18)
            HR().padding(.top, 26)
            if let mark = s.markUsd, let p = s.premiumPct { FairValueBlock(stock: s, mark: mark, premium: p) }
            stats(s)
        }
        .padding(.bottom, 24)
    }

    /// Apple Stocks header: logo + bold symbol with the name beside it, hairline, bold price + change, issuer · USD.
    private func hero(_ s: Stock) -> some View {
        let scrubbing = store.scrub != nil
        let price = store.scrub?.price ?? s.priceUsd
        let change = scrubbing ? store.scrubChange : s.change24h
        let abs: Double? = scrubbing
            ? zip2(store.scrub?.price, store.points.first?.price).map { $0 - $1 }
            : zip2(s.change24h, s.priceUsd).map { ch, p in p - p / (1 + ch / 100) }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Logo(url: s.logoURL, symbol: s.symbol, size: 40)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 6 }
                Text(s.symbol).font(.system(size: 34, weight: .bold)).tracking(-1).lineLimit(1).minimumScaleFactor(0.7)
                Text(s.name).font(.system(size: 17)).foregroundStyle(Theme.muted).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 14)
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Fmt.usd(price)).font(.system(size: 24, weight: .bold)).monospacedDigit().contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: price)
                Text(changeText(change, abs)).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(Theme.change(change))
            }
            .padding(.top, 14)
            Text(scrubbing ? Fmt.dateTime(store.scrub!.t) : "\(issuerLabel(s.issuer)) · USD · \(store.range.caption)")
                .font(.system(size: 17)).foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    private func changeText(_ pct: Double?, _ abs: Double?) -> String {
        guard let pct else { return "—" }
        var t = Fmt.pct(pct)
        if let abs { t = (abs >= 0 ? "+" : "−") + "$" + String(format: "%.2f", Swift.abs(abs)) + "  " + t }
        return t
    }

    private func issuerLabel(_ i: String) -> String {
        switch i { case "prestocks": "PreStocks"; case "xstocks": "xStocks"; case "backpack": "Backpack"; default: i }
    }

    @ViewBuilder private func chart(_ s: Stock) -> some View {
        let live = store.range == .live
        if store.chartLoading && store.points.isEmpty {
            Skeleton(height: live ? 260 : 200).padding(.horizontal, 20)
        } else {
            LineChart(points: store.points, live: live, height: live ? 260 : 200) { store.scrub = $0 }
                .animation(.easeOut(duration: 0.3), value: store.points.last?.price)
        }
    }

    /// LIVE · 1H · 1D · 7D▾ · ALL. The ▾ pill is a menu for 7D / 30D and shows whichever is picked.
    private var ranges: some View {
        HStack(spacing: 0) {
            Spacer(); rangePill(.live); Spacer(); rangePill(.h1); Spacer(); rangePill(.d1); Spacer()
            Menu {
                ForEach(HistoryRange.long) { r in
                    Button(r.label) { store.longRange = r; store.setRange(r) }
                }
            } label: {
                let on = HistoryRange.long.contains(store.range)
                HStack(spacing: 3) {
                    Text(store.longRange.label)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? skin.accent : Theme.muted)
                .frame(width: 56, height: 32)
                .background(on ? skin.accentTint : .clear, in: .capsule)
            }
            Spacer(); rangePill(.all); Spacer()
        }
    }

    private func rangePill(_ r: HistoryRange) -> some View {
        let on = store.range == r
        return Button { store.setRange(r) } label: {
            Text(r.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? skin.accent : Theme.muted)
                .frame(width: r == .live ? 52 : 44, height: 32)
                .background(on ? skin.accentTint : .clear, in: .capsule)
        }
        .buttonStyle(.plain)
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
                    KV("Market", s.marketOpen ? "Open" : "After hours · trades 24/7 here")
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

/// Premium to fair value. Chip + the two numbers + a -10…+10% gauge. Hidden when there is no mark.
struct FairValueBlock: View {
    let stock: Stock
    let mark: Double
    let premium: Double

    private var tone: Color {
        abs(premium) <= 0.25 ? Theme.muted : premium < 0 ? Theme.green : Theme.red
    }
    private var toneTint: Color {
        abs(premium) <= 0.25 ? Theme.greyT : premium < 0 ? Theme.greenT : Theme.redT
    }
    private var caption: String {
        if stock.isPreIPO {
            return "Fair value is PreStocks' mark from the company's last funding round. Above it means buyers are paying a premium."
        }
        var base = stock.symbol
        if base.count > 1, base.last?.lowercased() == "x" { base.removeLast() }
        return "Fair value is the live Nasdaq price for \(base). The token usually trades within 1% of it."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fair value").h2Text()
            VStack(alignment: .leading, spacing: 12) {
                Text("\(Fmt.pct(premium, 1)) vs fair value")
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(tone)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(toneTint, in: .capsule)
                HStack {
                    Text("\(Text(Fmt.usd(mark)).foregroundStyle(Theme.ink)) fair")
                    Spacer()
                    Text("\(Text(Fmt.usd(stock.priceUsd)).foregroundStyle(Theme.ink)) now")
                }
                .font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.muted)
                gauge
                Text(caption).font(.sub).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 20).padding(.top, 22)
    }

    /// Under = left of centre, over = right. Clamped at ±10%.
    private var gauge: some View {
        VStack(spacing: 6) {
            GeometryReader { g in
                let frac = 0.5 + min(10, max(-10, premium)) / 20
                let x = g.size.width * frac
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2).frame(height: 6)
                    Rectangle().fill(Theme.faint).frame(width: 1, height: 14).position(x: g.size.width / 2, y: 3)
                    Capsule().fill(tone).frame(width: 3, height: 16).position(x: x, y: 3)
                }
            }
            .frame(height: 16)
            HStack {
                Text("−10% under").frame(maxWidth: .infinity, alignment: .leading)
                Text("0").frame(maxWidth: .infinity)
                Text("+10% over").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(Theme.faint)
        }
        .padding(.top, 4)
    }
}
