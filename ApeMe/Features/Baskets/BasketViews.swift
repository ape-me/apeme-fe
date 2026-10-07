import SwiftUI

// MARK: - Home chip

/// The list, as cards. Everything on it is what /baskets returned.
struct BasketsSection: View {
    @Environment(AppState.self) private var app
    @State private var store = BasketsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Baskets").h2Text()
                Text("A whole theme in one tap, equal weight").font(.sub).foregroundStyle(Theme.muted)
            }
            if let err = store.error, store.baskets.isEmpty {
                ErrorBar(text: err).padding(.horizontal, -20)
            } else if store.baskets.isEmpty {
                VStack(spacing: 10) { Skeleton(height: 92); Skeleton(height: 92); Skeleton(height: 92) }
            } else {
                VStack(spacing: 10) {
                    ForEach(store.baskets) { b in BasketCard(basket: b) { app.push(.basket(b.id)) } }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
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
            .contentShape(.rect)
        }
        .buttonStyle(RowPress())
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
        case about, performance, risk, news
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

    private var d: BasketDetail? { store.detail }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BackButton(); Text(d?.name ?? "Basket").h2Text(); Spacer() }
                .padding(.horizontal, 12).padding(.top, 6).frame(height: 56)
            ScrollView {
                if let d {
                    VStack(alignment: .leading, spacing: 18) {
                        header(d)
                        ScrollView(.horizontal) {
                            UnderlineTabs(items: Tab.allCases, selected: tab, label: \.label) { tab = $0; Haptic.selection() }
                        }
                        .scrollIndicators(.hidden)
                        switch tab {
                        case .about: about(d)
                        case .performance: performance(d)
                        case .risk: risk(d)
                        case .news: newsTab
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 130)
                } else if let err = store.error {
                    ErrorBar(text: err)
                } else {
                    VStack(spacing: 12) { Skeleton(height: 60); Skeleton(height: 200); Skeleton(height: 64) }
                        .padding(.horizontal, 20).padding(.top, 20)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .safeAreaInset(edge: .bottom) { if let d { invest(d) } }
        .task { await store.load(id) }
        .task(id: tab) {
            guard tab == .news, !newsLoaded else { return }
            news = (try? await API.shared.basketNews(id).items) ?? []; newsLoaded = true
        }
    }

    private func header(_ d: BasketDetail) -> some View {
        HStack(alignment: .top, spacing: 14) {
            LogoStack(urls: (d.logos ?? []).compactMap(URL.init(string:)), size: 36)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.pct(d.return1y, 1))
                    .font(.system(size: 30, weight: .semibold)).tracking(-0.8).monospacedDigit()
                    .foregroundStyle(d.return1y == nil ? Theme.muted : Theme.change(d.return1y))
                Text(d.returnLabel ?? "1Y").font(.sub).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: About

    private func about(_ d: BasketDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let paras = d.about {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(paras, id: \.self) { Text($0).font(.body15).foregroundStyle(Theme.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("\(d.stocks.count) stocks, equal weight")
                VStack(spacing: 0) {
                    ForEach(d.stocks) { leg in
                        Button { app.openStock(leg.stock.mint) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Logo(url: leg.stock.logoURL, symbol: leg.stock.symbol)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(leg.stock.name).font(.rowTitle).tracking(-0.2).lineLimit(1)
                                        Text(String(format: "%.0f%%", leg.weight ?? 0)).font(.sub).monospacedDigit().foregroundStyle(Theme.faint)
                                    }
                                    if let why = leg.why { Text(why).font(.sub).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true) }
                                }
                                Spacer(minLength: 8)
                                Text(Fmt.pct(leg.return1y, 0)).font(.rowChange).monospacedDigit().foregroundStyle(Theme.change(leg.return1y))
                            }
                            .padding(.vertical, 10).contentShape(.rect)
                        }
                        .buttonStyle(RowPress())
                    }
                }
            }
            resources(d)
        }
    }

    /// Issuer, Solscan, Yahoo per stock. A null link is hidden, not shown dead — pre-IPO has no
    /// listing to point at.
    private func resources(_ d: BasketDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Resources")
            KCard {
                ForEach(d.stocks) { leg in
                    HStack(spacing: 10) {
                        Text(leg.stock.symbol).font(.system(size: 13, weight: .semibold)).frame(width: 84, alignment: .leading).lineLimit(1)
                        Spacer(minLength: 0)
                        ForEach([("Issuer", leg.links?.issuer), ("Solscan", leg.links?.solscan), ("Yahoo", leg.links?.yahoo)], id: \.0) { name, link in
                            if let link, let u = URL(string: link) {
                                Button(name) { openURL(u) }.font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink).buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 40)
                }
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

    private func invest(_ d: BasketDetail) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach([10, 25, 50, 100], id: \.self) { v in
                    Pill(label: "$\(v)", on: usd == Double(v), size: .small, wide: true) { amount = "\(v)" }
                }
            }
            HStack(spacing: 10) {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad).font(.system(size: 20, weight: .semibold)).monospacedDigit()
                    .padding(.horizontal, 14).frame(height: 52).background(Theme.surface, in: .capsule)
                BigButton(label: !d.canTrade ? "Market closed" : usd < minUsd ? "Min \(Fmt.cash(minUsd))" : "Invest \(Fmt.cash(usd))",
                          style: d.canTrade && usd >= minUsd ? .buy : .off) {
                    guard d.canTrade, usd >= minUsd else { return }
                    guard app.walletAddress != nil else { app.sheet = .login; return }
                    Haptic.medium(); app.sheet = .basket(d, amountUsd: usd)
                }
            }
            Text("1% fee on each swap · min \(Fmt.cash(minUsd))").font(.system(size: 11)).foregroundStyle(Theme.faint)
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
