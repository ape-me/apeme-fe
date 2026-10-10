import SwiftUI

// MARK: - Home chip

/// What this phone looked at, then the baskets as a grid. "Recently viewed" exists only once
/// there is something in it; an empty section with a heading is a shelf with nothing on it.
struct BasketsSection: View {
    @Environment(AppState.self) private var app
    private var store: BasketsStore { BasketsStore.shared }

    private var recent: [Stock] { app.recent.compactMap { app.stocksByMint[$0] } }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !recent.isEmpty { recentlyViewed }
            VStack(alignment: .leading, spacing: 14) {
                Text("Baskets").h2Text()
                buildCard
                if let err = store.error, store.baskets.isEmpty {
                    ErrorBar(text: err).padding(.horizontal, -20)
                } else if store.baskets.isEmpty {
                    BasketsGridSkeleton(heading: false)
                } else {
                    LazyVGrid(columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(store.baskets.prefix(3)) { b in BasketTile(basket: b) { app.push(.basket(b.id)) } }
                        seeMore
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
        .task { await store.load() }
    }

    private var recentlyViewed: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recently viewed").h2Text()
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(recent) { s in
                        Button { app.openStock(s.mint) } label: {
                            VStack(spacing: 8) {
                                Logo(url: s.logoURL, symbol: s.symbol, size: 56)
                                Text(s.symbol).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                Text(Fmt.pct(s.change24h, 2)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                                    .foregroundStyle(Theme.change(s.change24h))
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(RowPress())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Describe an idea, get a basket. The four ideas are the backend's and change with the news.
    private var buildCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { app.push(.buildBasket(nil)) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accent)
                        .frame(width: 40, height: 40).background(Theme.accent.opacity(0.10), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Build a basket from an idea").font(.rowTitle).tracking(-0.2)
                        Text("Say what you believe. The AI picks the stocks.").font(.sub).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if !store.ideas.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.ideas, id: \.self) { i in Pill(label: i, size: .small) { app.push(.buildBasket(i)) } }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }

    /// The rest of the shelf, four logos as a hint of what is behind it.
    private var seeMore: some View {
        Button { app.push(.baskets) } label: {
            VStack(alignment: .leading, spacing: 0) {
                let rest = store.baskets.dropFirst(3)
                SpreadLogos(urls: rest.prefix(4).compactMap { $0.logoURLs.first }, size: 28)
                Spacer(minLength: 12)
                HStack(spacing: 4) {
                    Text("See more").font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 10)
                Text("\(rest.count) more").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.muted)
                Text("baskets").font(.sub).foregroundStyle(Theme.faint)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1)).contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }
}

/// One basket as a grid tile: logos, name, the return and its period.
struct BasketTile: View {
    let basket: Basket
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                SpreadLogos(urls: basket.logoURLs, size: 28)
                Spacer(minLength: 12)
                Text(basket.name).font(.system(size: 15, weight: .semibold)).tracking(-0.2).lineLimit(1)
                Spacer(minLength: 10)
                Text(Fmt.pct(basket.return1y, 1)).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(basket.return1y == nil ? Theme.muted : Theme.change(basket.return1y))
                Text(basket.returnLabel ?? "1Y").font(.sub).foregroundStyle(Theme.faint)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1)).contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }
}

/// Every basket, as rows. Reached from See more.
struct BasketsListView: View {
    @Environment(AppState.self) private var app
    private var store: BasketsStore { BasketsStore.shared }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BackButton(); Text("Baskets").h2Text(); Spacer() }
                .padding(.horizontal, 12).padding(.top, 6).frame(height: 56)
            ScrollView {
                VStack(spacing: 10) {
                    if let err = store.error, store.baskets.isEmpty { ErrorBar(text: err) }
                    ForEach(store.baskets) { b in BasketCard(basket: b) { app.push(.basket(b.id)) } }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .task { await store.load() }
    }
}

struct BasketCard: View {
    let basket: Basket
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                LogoStack(urls: basket.logoURLs)
                VStack(alignment: .leading, spacing: 3) {
                    Text(basket.name).font(.rowTitle).tracking(-0.2)
                    if let t = basket.tagline { Text(t).font(.sub).foregroundStyle(Theme.muted).lineLimit(1) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.pct(basket.return1y, 1)).font(.rowPrice).monospacedDigit()
                        .foregroundStyle(basket.return1y == nil ? Theme.muted : Theme.change(basket.return1y))
                    Text(basket.returnLabel ?? "1Y").font(.sub).foregroundStyle(Theme.faint)
                }
            }
            .padding(14)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }
}

/// Up to five logos spread evenly across the width they are given, for a tile: a stack huddled
/// in the corner left the rest of the tile empty.
struct SpreadLogos: View {
    let urls: [URL]
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(urls.prefix(5).enumerated()), id: \.offset) { i, u in
                if i > 0 { Spacer(minLength: 2) }
                RemoteImage(url: u, fallback: "")
                    .frame(width: size, height: size)
                    .clipShape(.circle)
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Up to five logos overlapping, the way a basket of things reads at a glance.
struct LogoStack: View {
    let urls: [URL]
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(Array(urls.prefix(5).enumerated()), id: \.offset) { _, u in
                RemoteImage(url: u, fallback: "")
                    .frame(width: size, height: size)
                    .clipShape(.circle)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
            }
        }
        // Always the width of five, so the name column starts at the same place on every card
        // whether the basket holds three stocks or seven.
        .frame(width: size + 4 * size * 0.68, alignment: .leading)
    }
}

// MARK: - Basket page

struct BasketView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case about, mix, performance, risk, news
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    let id: String
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL
    @State private var store = BasketsStore()
    @State private var tab: Tab = .about
    @State private var range = "1Y"
    @State private var news: [NewsItem] = []
    @State private var newsLoaded = false
    @State private var amount = ""
    @State private var mix = MixStore()

    private var d: BasketDetail? { store.detail }

    var body: some View {
        // The cover is the top of the page and scrolls with it; the back button is pinned over
        // the cover's empty band so it is still there once the cover has gone.
        ZStack(alignment: .top) {
            ScrollView {
                if let d {
                    VStack(alignment: .leading, spacing: 0) {
                        header(d)
                        VStack(alignment: .leading, spacing: 18) {
                            if d.isAI { aiStrip(d) }
                            ScrollView(.horizontal) {
                                UnderlineTabs(items: Tab.allCases, selected: tab, label: \.label) { tab = $0; Haptic.selection() }
                            }
                            .scrollIndicators(.hidden)
                            switch tab {
                            case .about: about(d)
                            case .mix: MixView(d: d, store: mix)
                            case .performance: performance(d)
                            case .risk: risk(d)
                            case .news: newsTab
                            }
                        }
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 130)
                    }
                    // Exactly the viewport wide. Four flexible cells in the cover's stat strip
                    // round up by a fraction of a point, and a vertical scroll view whose content
                    // is a hair too wide starts rubber-banding sideways.
                    .containerRelativeFrame(.horizontal, alignment: .leading)
                } else if let err = store.error {
                    ErrorBar(text: err).padding(.top, 56)
                } else {
                    // Cover, tab strip, two paragraphs, a heading, then stock rows — the About
                    // tab's shape, in its places.
                    VStack(alignment: .leading, spacing: 0) {
                        BasketCoverSkeleton()
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 14) {
                                ForEach([52, 96, 40, 48], id: \.self) { w in Skeleton(height: 16).frame(width: CGFloat(w)) }
                            }
                            .frame(height: 40)
                            VStack(alignment: .leading, spacing: 10) {
                                Skeleton(height: 16); Skeleton(height: 16).frame(width: 150)
                                Skeleton(height: 16).frame(width: 280).padding(.top, 4)
                            }
                            Skeleton(height: 20).frame(width: 190)
                            ForEach(0..<4, id: \.self) { _ in RowSkeleton(spark: false) }
                        }
                        .padding(.horizontal, 20).padding(.top, 16)
                    }
                    .containerRelativeFrame(.horizontal, alignment: .leading)
                }
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 10) { BackButton(); Spacer() }
                .padding(.horizontal, 12).frame(height: 56)
        }
        .background(Theme.ground)
        .safeAreaInset(edge: .bottom) { if let d { invest(d) } }
        .task { await store.load(id); if let d { mix.load(d) } }
        .task { if app.wallet == nil { await app.loadWallet() } }
        .task(id: tab) {
            guard tab == .news, !newsLoaded else { return }
            news = (try? await API.shared.basketNews(id).items) ?? []; newsLoaded = true
        }
    }

    private func header(_ d: BasketDetail) -> some View {
        BasketCover(name: d.name, tagline: d.tagline, logos: (d.logos ?? []).prefix(5).compactMap(URL.init(string:)),
                    chart: d.chart?.points.map(\.value) ?? [], chartTint: Theme.change(d.return1y), stats: coverStats(d))
    }

    /// The same four cells on every basket, in the same order, so the eye learns where to look:
    /// the return over the period, the index over the same period, how rough the ride is, and
    /// which stock carried it. A cell the backend cannot fill shows a dash rather than a
    /// different stat that happens to exist.
    private func coverStats(_ d: BasketDetail) -> [CoverStat] {
        // "408% ↑" where "408.1% ↑" would not fit the cell. The colour says the sign already;
        // the arrow after the number says it again for anyone who does not read colour.
        func pct(_ r: Double?) -> String { r.map { Fmt.trailingArrow($0, abs($0) >= 100 ? 0 : 1) } ?? "—" }
        let bench = d.performance?.benchmark
        let benchReturn = bench?.returnPct
        return [
            .init(label: d.returnLabel ?? "1Y", value: pct(d.return1y), color: Theme.change(d.return1y)),
            .init(label: "vs \(bench?.name ?? "S&P 500")", value: pct(benchReturn), color: Theme.change(benchReturn)),
            .init(label: "Risk", value: d.risk?.level ?? "—"),
            .init(label: "Best" + (d.best?.return1y.map { " · \(Fmt.trailingArrow($0, 0))" } ?? ""), value: d.best?.symbol ?? "—",
                  color: Theme.change(d.best?.return1y)),
        ]
    }

    // MARK: About

    private func about(_ d: BasketDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let paras = d.about {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(paras, id: \.self) { Text($0).font(.body15).foregroundStyle(Theme.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("\(d.stocks.count) stocks") {
                    Button { tab = .mix; Haptic.selection() } label: {
                        HStack(spacing: 4) { Text("Change the mix"); Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }
                            .font(.sub.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                }
                ForEach(d.stocks) { leg in pickCard(leg, d) }
            }
            if let bear = d.ai?.bearCase, !bear.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The bear case").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.red)
                    Text(bear).font(.sub).foregroundStyle(Theme.ink).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.redT, in: .rect(cornerRadius: 12))
            }
            if d.isAI {
                Text("AI picks, not advice. Check the stocks before you buy.").font(.system(size: 11)).foregroundStyle(Theme.faint)
            }
        }
    }

    /// One pick as a card: the mark, the name, why it is in, the story behind it, and its share
    /// as a chip that opens the mix. The row itself opens the stock.
    private func pickCard(_ leg: BasketDetail.Leg, _ d: BasketDetail) -> some View {
        let w = Int((leg.weight ?? 0).rounded())
        return VStack(alignment: .leading, spacing: 10) {
            Button { app.openStock(leg.stock.mint) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Logo(url: leg.stock.logoURL, symbol: leg.stock.symbol)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(leg.stock.name).font(.rowTitle).tracking(-0.2).lineLimit(1)
                            Text(leg.stock.symbol).font(.sub).foregroundStyle(Theme.faint)
                        }
                        if let why = leg.why { Text(why).font(.sub).foregroundStyle(Theme.muted).lineLimit(3).fixedSize(horizontal: false, vertical: true) }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(w)%").font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8).frame(height: 24).background(Theme.accent.opacity(0.10), in: .capsule)
                        Text("\(Fmt.pct(leg.return1y, 0)) \(d.returnLabel ?? "1Y")").font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(Theme.change(leg.return1y))
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if let n = leg.news, let title = n.title {
                Rectangle().fill(Theme.line).frame(height: 1)
                Button { if let u = n.link { openURL(u) } } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "newspaper").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.faint).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.sub).foregroundStyle(Theme.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            Text([n.source, n.publishedAt.map { Fmt.monthDay($0) }].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 11)).foregroundStyle(Theme.faint)
                        }
                        Spacer(minLength: 0)
                        if n.link != nil { Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.faint) }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    /// Under the cover of a basket the AI built: what was asked, and what this is not.
    private func aiStrip(_ d: BasketDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
                Text("AI pick, not advice").font(.system(size: 11, weight: .semibold)).tracking(0.2)
            }
            .foregroundStyle(Theme.accent)
            if let idea = d.ai?.idea, !idea.isEmpty {
                Text("You asked: ").font(.sub).foregroundStyle(Theme.muted) + Text("“\(idea)”").font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
            }
        }
    }

    // MARK: Performance

    private static let rangeDays: [String: Int] = ["1M": 30, "3M": 91, "6M": 182, "1Y": 365]

    private func slice(_ pts: [BasketDetail.ChartPoint]?) -> [BasketDetail.ChartPoint] {
        guard let pts, let days = Self.rangeDays[range] else { return [] }
        let since = Int(Date.now.timeIntervalSince1970) - days * 86_400
        let cut = pts.filter { $0.t >= since }
        guard let first = cut.first, first.value > 0 else { return cut }
        // Re-based so the slice starts at 100, which is what a range toggle means.
        return cut.map { .init(t: $0.t, value: $0.value / first.value * 100) }
    }

    private func performance(_ d: BasketDetail) -> some View {
        let perf = d.performance
        let value = perf?.ranges?[range] ?? nil
        let bench = perf?.benchmark
        let benchValue = bench?.ranges?[range] ?? nil
        let basketPts = slice(d.chart?.points)
        let benchPts = slice(bench?.points)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(["1M", "3M", "6M", "1Y"], id: \.self) { r in
                    let enabled = (perf?.ranges?[r] ?? nil) != nil
                    Pill(label: r, on: range == r, size: .small, wide: true) { if enabled { range = r; Haptic.selection() } }
                        .opacity(enabled ? 1 : 0.35)
                }
            }
            if value == nil {
                // Not enough history for any range (pre-IPO): the headline return still stands.
                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.pct(d.return1y, 1)).font(.system(size: 26, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.change(d.return1y))
                    Text(d.returnLabel ?? "since listing").font(.sub).foregroundStyle(Theme.muted)
                }
            } else {
                Text("\(d.name) \(Fmt.pct(value, 1))" + (benchValue != nil ? "  vs  \(bench?.name ?? "S&P 500") \(Fmt.pct(benchValue, 1))" : ""))
                    .font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
            if basketPts.count > 1 {
                DualLineChart(primary: basketPts.map { ($0.t, $0.value) }, secondary: benchPts.map { ($0.t, $0.value) },
                              tint: Theme.change(value ?? d.return1y))
                    .frame(height: 180)
                HStack(spacing: 14) {
                    legend(Theme.change(value ?? d.return1y), d.name)
                    if !benchPts.isEmpty { legend(Theme.faint, bench?.name ?? "S&P 500") }
                }
            }
            if d.best != nil || d.worst != nil {
                HStack(spacing: 10) {
                    if let b = d.best { extreme("Best", b) }
                    if let w = d.worst { extreme("Worst", w) }
                }
            }
        }
    }

    private func legend(_ c: Color, _ name: String) -> some View {
        HStack(spacing: 6) { Capsule().fill(c).frame(width: 14, height: 3); Text(name).font(.sub).foregroundStyle(Theme.muted) }
    }

    private func extreme(_ label: String, _ e: BasketDetail.Extreme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.sub).foregroundStyle(Theme.muted)
            Text(e.symbol).font(.system(size: 16, weight: .semibold))
            Text(Fmt.pct(e.return1y, 1)).font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.change(e.return1y))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }

    // MARK: Risk

    @ViewBuilder private func risk(_ d: BasketDetail) -> some View {
        if let r = d.risk {
            VStack(alignment: .leading, spacing: 16) {
                if let level = r.level {
                    let tint: Color = level == "Low" ? Theme.green : level == "High" ? Theme.red : Theme.amber
                    let fill: Color = level == "Low" ? Theme.greenT : level == "High" ? Theme.redT : Theme.amberT
                    Text(level.uppercased() + " RISK").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(tint)
                        .padding(.horizontal, 12).frame(height: 32).background(fill, in: .capsule)
                }
                KCard {
                    if let v = r.volatilityPct { KV("Swings", String(format: "%.1f%% a year", v)) }
                    if let dd = r.maxDrawdown, let pct = dd.pct {
                        riskRow("Biggest drop", Fmt.pct(pct, 1), (dd.from != nil && dd.to != nil) ? "\(Fmt.date(dd.from!)) → \(Fmt.date(dd.to!))" : nil, Theme.red)
                    }
                    if let w = r.worstDay, let pct = w.pct { riskRow("Worst day", Fmt.pct(pct, 1), w.t.map(Fmt.date), Theme.red) }
                    if let b = r.bestDay, let pct = b.pct { riskRow("Best day", Fmt.pct(pct, 1), b.t.map(Fmt.date), Theme.green) }
                }
                if let notes = r.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(notes, id: \.self) { n in
                            HStack(alignment: .top, spacing: 8) { Text("•"); Text(n).fixedSize(horizontal: false, vertical: true) }
                                .font(.sub).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        } else {
            EmptyState(title: "Not enough history yet.", subtitle: "Risk figures need a few weeks of prices.")
        }
    }

    /// The figure on the row, the dates under it — inline they ran off the right edge.
    private func riskRow(_ label: String, _ value: String, _ when: String?, _ tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.muted)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(tint)
                if let when { Text(when).font(.sub).foregroundStyle(Theme.faint) }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: News

    @ViewBuilder private var newsTab: some View {
        if !newsLoaded { NewsListSkeleton() }
        else if news.isEmpty { EmptyState(title: "No news this week.", subtitle: "Stories about these stocks land here.") }
        else { NewsList(items: news, open: { openArticle($0, openURL) }, openStock: { app.openStock($0) }) }
    }

    // MARK: Invest bar

    private var usd: Double { Double(amount) ?? 0 }
    private var minUsd: Double { d?.minUsd ?? 10 }
    /// Spendable USDC, floored to the cent. nil until the wallet has been read; signed out is 0.
    private var cash: Double? { app.walletAddress == nil ? 0 : app.wallet.map { floor(($0.cashUsd ?? 0) * 100) / 100 } }
    private var short: Bool { cash.map { usd > $0 + 0.0001 } ?? false }

    private func invest(_ d: BasketDetail) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // A chip above the balance is not an option, so it does not light up.
                ForEach([10, 25, 50, 100], id: \.self) { v in
                    let ok = cash.map { Double(v) <= $0 } ?? true
                    Pill(label: "$\(v)", on: usd == Double(v), size: .small, wide: true) { amount = "\(v)" }
                        .opacity(ok ? 1 : 0.35).disabled(!ok)
                }
                if let c = cash, c >= minUsd {
                    Pill(label: "Max", on: usd == c, size: .small, wide: true) { amount = Fmt.plain(c) }
                }
            }
            HStack(spacing: 10) {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad).font(.system(size: 20, weight: .semibold)).monospacedDigit()
                    .padding(.horizontal, 14).frame(height: 52).background(Theme.surface, in: .capsule)
                    .overlay(Capsule().stroke(short ? Theme.red : Theme.line, lineWidth: 1))
                let open = d.canTrade || !mix.active.contains { t in d.stocks.first { $0.key == t }?.stock.tradable == false }
                BigButton(label: !open ? "Market closed" : short ? "Not enough USDC" : usd < minUsd ? "Min \(Fmt.cash(minUsd))" : "Invest \(Fmt.cash(usd))\(mix.changed ? " · your mix" : "")",
                          style: open && usd >= minUsd && !short ? .buy : .off) {
                    guard open, usd >= minUsd, !short else { return }
                    guard app.walletAddress != nil else { app.sheet = .login; return }
                    Haptic.medium(); app.sheet = .basket(d, amountUsd: usd, weights: mix.changed ? mix.sendable : nil)
                }
            }
            if !d.canTrade, mix.active.contains(where: { t in d.stocks.first { $0.key == t }?.stock.tradable == false }) {
                // Say which stock shut the basket, not just that it is shut. Ondo names close
                // Friday 8pm ET and open Sunday 8pm ET; the others trade around the clock.
                let closed = d.stocks.filter { $0.stock.tradable == false }.map(\.stock.symbol)
                Text(closed.isEmpty ? "Closed right now. Try again later."
                     : "\(closed.joined(separator: ", ")) \(closed.count == 1 ? "is" : "are") closed until Sunday 8pm ET. Take \(closed.count == 1 ? "it" : "them") out in Mix to buy the rest.")
                    .font(.system(size: 11)).foregroundStyle(Theme.amber).multilineTextAlignment(.center)
            } else {
                Text(cash.map { "You have \(Fmt.cash($0)) · 1% fee on each swap · min \(Fmt.cash(minUsd))" } ?? "1% fee on each swap · min \(Fmt.cash(minUsd))")
                    .font(.system(size: 11)).foregroundStyle(short ? Theme.red : Theme.faint)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.ground)
    }
}

/// Two series on one scale: the basket, and the benchmark dimmer behind it. Both are re-based
/// to 100 at the start of the range, so the gap between the lines is the comparison.
struct DualLineChart: View {
    struct Pt: Hashable { let t: Int; let v: Double }
    let primary: [Pt]
    let secondary: [Pt]
    let tint: Color

    init(primary: [(Int, Double)], secondary: [(Int, Double)], tint: Color) {
        self.primary = primary.map { Pt(t: $0.0, v: $0.1) }
        self.secondary = secondary.map { Pt(t: $0.0, v: $0.1) }
        self.tint = tint
    }

    /// The shared scale, worked out once per layout rather than inline in the view builder.
    private struct Scale {
        let lo: Double, span: Double, t0: Int, tspan: Int, size: CGSize
        init(_ a: [Pt], _ b: [Pt], _ size: CGSize) {
            let vals = a.map(\.v) + b.map(\.v)
            lo = vals.min() ?? 0
            span = max((vals.max() ?? 1) - lo, 0.0001)
            let ts = (a + b).map(\.t)
            t0 = ts.min() ?? 0
            tspan = max((ts.max() ?? 1) - t0, 1)
            self.size = size
        }
        func point(_ p: Pt) -> CGPoint {
            CGPoint(x: CGFloat(p.t - t0) / CGFloat(tspan) * size.width,
                    y: size.height - CGFloat((p.v - lo) / span) * size.height)
        }
        func y(_ v: Double) -> CGFloat { size.height - CGFloat((v - lo) / span) * size.height }
        func path(_ pts: [Pt]) -> Path {
            var path = Path()
            for (i, p) in pts.enumerated() {
                let xy = point(p)
                if i == 0 { path.move(to: xy) } else { path.addLine(to: xy) }
            }
            return path
        }
    }

    var body: some View {
        GeometryReader { g in
            let s = Scale(primary, secondary, g.size)
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: s.y(100))); p.addLine(to: CGPoint(x: g.size.width, y: s.y(100))) }
                    .stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                s.path(secondary).stroke(Theme.faint.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                s.path(primary).stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
