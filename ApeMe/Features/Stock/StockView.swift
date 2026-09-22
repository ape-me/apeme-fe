import SwiftUI

struct StockView: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @Environment(\.openURL) private var openURL
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
                .containerRelativeFrame(.horizontal)
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
        .task { await store.loadInsights() }
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
                BigButton(label: "Buy", style: .buy) { app.trade(.buyStock(s)) }
                BigButton(label: "Sell", style: .sell) { app.sell(store.mint) }
            }
            .padding(.horizontal, 20).padding(.top, 18)
            if let ins = store.insights {
                EarningsNote(insights: ins).padding(.horizontal, 20).padding(.top, 22)
            }
            HR().padding(.top, 22)
            tabs.padding(.top, 18)
            Group {
                switch store.tab {
                case .overview: overview(s)
                case .news: newsTab(s)
                case .about: about(s)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(StockStore.Tab.allCases) { t in
                Button {
                    Haptic.selection()
                    store.tab = t
                    if t == .news { store.unreadNews = false }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Text(t.label)
                            if t == .news, store.unreadNews {
                                Circle().fill(skin.accent).frame(width: 6, height: 6)
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(store.tab == t ? Theme.ink : Theme.faint)
                        Rectangle().fill(store.tab == t ? Theme.ink : .clear).frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Three cards: is it cheap, where is it in its year, is it busy here.
    private func overview(_ s: Stock) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let mark = s.markUsd, let p = s.premiumPct {
                FairValueBlock(stock: s, mark: mark, premium: p, insights: store.insights)
            }
            if let stats = store.insights?.stats, let price = s.priceUsd {
                YearRangeCard(stats: stats, price: price)
            } else if store.insightsLoading {
                InsightCardSkeleton(title: "Past 12 months", height: 92)
            }
            TradingHereCard(stock: s)
            if let d = store.insights?.dividends { DividendCard(dividends: d) }
            else if store.insightsLoading { InsightCardSkeleton(title: "Dividends", height: 84) }
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    @ViewBuilder private func newsTab(_ s: Stock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let err = store.newsError, store.news.isEmpty {
                ErrorBar(text: err).padding(.top, 18)
            } else if store.news.isEmpty, !store.newsLoaded {
                NewsListSkeleton(count: 3, showThumb: false)
            } else if store.news.isEmpty {
                EmptyState(title: "No news yet for \(s.symbol)",
                           subtitle: "Headlines land here within 20 minutes of publication.")
            } else {
                NewsList(items: store.news, showSymbol: false, showThumb: false,
                         open: { openArticle($0, openURL) }, openStock: { app.openStock($0) })
                if !store.newsExhausted {
                    BigButton(label: store.newsLoading ? "Loading…" : "More headlines", style: .ghost) {
                        Task { await store.moreNews() }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .padding(.horizontal, 20)
        .task(id: store.tab) { if store.tab == .news { await store.loadNews() } }
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
            Text(scrubbing ? Fmt.dateTime(store.scrub!.t) : store.range.caption.capitalized)
                .font(.system(size: 17)).foregroundStyle(Theme.muted)
                .padding(.top, 4)
            if let ins = store.insights, !scrubbing { NasdaqLine(insights: ins).padding(.top, 8) }
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
            LineChart(points: store.points, tint: store.direction, live: live, height: live ? 260 : 200) { store.scrub = $0 }
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

    /// The reference tab: who the company is, the analyst numbers, then the chain plumbing.
    private func about(_ s: Stock) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if let c = store.insights?.company, c.name != nil {
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle("Company")
                    KCard {
                        if let v = c.name { KV("Company", v) }
                        if let v = c.sector { KV("Sector", v) }
                        if let v = c.exchange { KV("Exchange", v) }
                        if let v = c.ipo, let d = Self.ipoDate(v) { KV("IPO", d) }
                        if let url = c.websiteURL, let host = c.host {
                            KV("Website") {
                                Link(destination: url) {
                                    Text("\(host) ↗").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                }
                            }
                        }
                    }
                }
            }
            investorStats
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("On chain")
                KCard {
                    KV("Issued by", issuerLabel(s.issuer))
                    KV("Trades in", "USD")
                    KV("Mint address") { CopyButton(text: Fmt.short(s.mint), value: s.mint) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    /// The analyst numbers still exist — they just don't ambush anyone on Overview.
    @ViewBuilder private var investorStats: some View {
        if let st = store.insights?.stats {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("For investors")
                KCard {
                    if let v = st.marketCapUsd { KV("Market cap", Fmt.big(v)) }
                    // Finnhub returns no P/E when trailing earnings are negative — an em dash, not a bug.
                    KV("P/E (TTM)", st.peTtm.map { String(format: "%.2f", $0) } ?? "—")
                    if let v = st.epsTtm { KV("Earnings per share", Fmt.usd(v)) }
                    if let e = store.insights?.earnings, let day = e.day {
                        KV("Next earnings", "\(Self.shortDate.string(from: day))\(e.when.map { " · \($0)" } ?? "")")
                    }
                }
            }
        }
    }

    private static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; f.timeZone = .gmt; return f
    }()

    private static func ipoDate(_ s: String) -> String? {
        let parse = DateFormatter(); parse.dateFormat = "yyyy-MM-dd"; parse.timeZone = .gmt
        guard let d = parse.date(from: s) else { return nil }
        let out = DateFormatter(); out.dateFormat = "MMM d, yyyy"; out.timeZone = .gmt
        return out.string(from: d)
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

/// Premium to fair value as three plain rows: what you pay, what it's worth, the gap.
/// Same card pattern as Market stats. Premium badge is grey under 5%, amber at or above.
struct FairValueBlock: View {
    let stock: Stock
    let mark: Double
    let premium: Double
    var insights: Insights?

    private var neutral: Bool { abs(premium) <= 0.25 }
    private var gapUsd: Double? { stock.priceUsd.map { $0 - mark } }
    private var sentence: String {
        let what = stock.isPreIPO ? "PreStocks' mark from the last funding round" : "the real share price"
        guard !neutral, let gap = gapUsd else { return "Trading at fair value — \(what)." }
        let dir = premium > 0 ? "more" : "less"
        return "You're paying \(Fmt.usd(abs(gap))) \(dir) than \(what)."
    }

    /// "It's worth" says nothing; "Real INTC share" says exactly what the number is.
    private var worthLabel: String {
        if stock.isPreIPO { return "Last funding round" }
        let ticker = insights?.ticker ?? String(stock.symbol.dropLast(stock.symbol.hasSuffix("X") ? 1 : 0))
        return "Real \(ticker) share"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Fair value")
            KCard {
                KV("You pay", Fmt.usd(stock.priceUsd))
                KV(worthLabel, Fmt.usd(mark))
                KV(premium > 0 ? "Premium" : premium < 0 ? "Discount" : "Gap") {
                    HStack(spacing: 8) {
                        if let gap = gapUsd, !neutral { Text(Fmt.usd(abs(gap))) }
                        PremiumBadge(pct: premium)
                    }
                }
                Text(sentence).font(.sub).foregroundStyle(Theme.muted).lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
            }
        }
    }
}
