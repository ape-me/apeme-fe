import SwiftUI

struct PreIPOSection: View {
    let stocks: [Stock]
    @Environment(AppState.self) private var app
    @State private var page: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.isApe ? "Pre-IPO floors" : "Before the IPO").h2Text()
                Text(app.isApe ? "Ranked by heat: launches, apes and volume" : "Private companies, before the IPO")
                    .font(.sub).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(stocks.prefix(3)) { s in
                        FeatureCard(stock: s)
                            .containerRelativeFrame(.horizontal) { w, _ in w - 40 }
                            .id(s.mint)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
            HStack(spacing: 5) {
                ForEach(stocks.prefix(3)) { s in
                    Circle().fill((page ?? stocks.first?.mint) == s.mint ? Theme.muted : Theme.line).frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            HR()
            VStack(spacing: 0) {
                ForEach(stocks.dropFirst(3)) { StockRow(stock: $0) }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 26)
    }
}

/// The paged hero card. Invest: price + fair value. Ape: floor volume + king.
struct FeatureCard: View {
    let stock: Stock
    @Environment(AppState.self) private var app

    var body: some View {
        Button { app.openStock(stock.mint) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Logo(url: stock.logoURL, symbol: stock.symbol, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.isApe ? "\(stock.symbol) floor" : stock.symbol).h3Text()
                        Text(app.isApe ? "\(stock.memes) memes · \(stock.launched24h ?? 0) launched today" : "\(stock.name) · Pre-IPO")
                            .font(.sub).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if app.isApe, let k = stock.king { Avatar(url: k.imageURL, symbol: k.symbol, size: 28) }
                    else if !app.isApe { PremiumBadge(pct: stock.premiumPct) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.isApe ? Fmt.big(stock.memeVol24hUsd) : Fmt.usd(stock.priceUsd))
                        .font(.system(size: 34, weight: .semibold)).tracking(-1.5).monospacedDigit()
                    if app.isApe {
                        Text("traded on the floor today · \(Fmt.n(stock.wallets24h)) apes").font(.sub).foregroundStyle(Theme.muted)
                    } else {
                        HStack(spacing: 4) {
                            Text(Fmt.arrow(stock.change24h)).foregroundStyle(Theme.change(stock.change24h))
                            Text("today").foregroundStyle(Theme.muted).fontWeight(.medium)
                        }
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    }
                }
                footer
            }
            .padding(18)
            .background(Theme.surface, in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var footer: some View {
        if app.isApe {
            HStack {
                if let k = stock.king {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(Theme.amber)
                        Text("King: \(Text(k.symbol).foregroundStyle(Theme.ink).fontWeight(.semibold)) · \(Fmt.big(k.vol24hUsd))")
                    }
                } else { Text("No king yet") }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .font(.sub).foregroundStyle(Theme.muted)
            .padding(.top, 12).overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        } else if let mark = stock.markUsd, let p = stock.premiumPct {
            let hot = abs(p) >= 5
            let pctText = abs(p) < 1 ? String(format: "%.1f", abs(p)) : String(format: "%.0f", abs(p))
            HStack {
                Text("Fair value \(Text(Fmt.usd(mark)).foregroundStyle(Theme.ink).fontWeight(.semibold)) · trades \(Text("\(pctText)% \(p >= 0 ? "above" : "below")").foregroundStyle(hot ? Theme.amber : Theme.ink).fontWeight(.semibold))")
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            }
            .font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
            .padding(.top, 12).overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }
}

struct MoversSection: View {
    @Bindable var store: HomeStore
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Biggest movers today").h2Text()
                Spacer()
                HStack(spacing: 4) {
                    Pill(label: "Gainers", on: store.moversSide == 0, size: .xsmall) { store.moversSide = 0 }
                    Pill(label: "Losers", on: store.moversSide == 1, size: .xsmall) { store.moversSide = 1 }
                }
            }
            let list = (store.moversSide == 0 ? store.movers?.gainers : store.movers?.losers) ?? []
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(list.prefix(4)) { s in MiniCard(stock: s) }
            }
            Text("Most traded").h2Text().padding(.top, 12)
            VStack(spacing: 0) {
                ForEach((store.movers?.mostTraded ?? []).prefix(5)) { StockRow(stock: $0) }
            }
        }
        .padding(.horizontal, 20).padding(.top, 26)
    }
}

struct MiniCard: View {
    let stock: Stock
    @Environment(AppState.self) private var app
    var body: some View {
        Button { app.openStock(stock.mint) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Logo(url: stock.logoURL, symbol: stock.symbol, size: 32)
                    Text(stock.symbol).h3Text()
                }
                Text(stock.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted).lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.usd(stock.priceUsd)).font(.stat).tracking(-0.5).monospacedDigit()
                    Text(Fmt.arrow(stock.change24h)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Theme.change(stock.change24h))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct ExploreSection: View {
    @Bindable var store: HomeStore
    @Environment(AppState.self) private var app

    var body: some View {
        let cols = store.collections.filter { $0.id != "preipo" }
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(cols) { c in
                        Pill(label: c.title, on: store.exploreId == c.id, size: .small) { store.exploreId = c.id }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            if let c = cols.first(where: { $0.id == store.exploreId }) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach((c.stocks ?? []).prefix(6)) { StockRow(stock: $0) }
                    Button { app.root(.markets) } label: {
                        HStack(spacing: 4) { Text("See all in Markets"); Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)) }
                            .font(.sub.weight(.semibold)).frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 26)
    }
}

struct WatchSection: View {
    @Bindable var store: HomeStore
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            if store.watched.isEmpty {
                EmptyState(title: "Nothing watched yet", subtitle: "Tap the star on any stock to keep it here.") {
                    Button { app.root(.markets) } label: {
                        HStack(spacing: 4) { Text("Explore markets"); Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)) }
                            .font(.sub.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(store.watched) { StockRow(stock: $0) }
            }
        }
        .padding(.horizontal, 20).padding(.top, 26)
        .task(id: app.watch) { await store.loadWatch(app: app) }
    }
}

struct NewLaunchesSection: View {
    @Bindable var store: HomeStore
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Just launched").h2Text()
                    Text("New tokens across every floor").font(.sub).foregroundStyle(Theme.muted)
                }
                Spacer()
                StatusChip(text: store.socketStatus.rawValue, live: store.socketStatus == .live)
            }
            if store.newTokens.isEmpty {
                Skeleton(height: 64); Skeleton(height: 64)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.newTokens) { t in
                        TokenRow(token: t, stockSymbol: app.stocksByMint[t.quoteMint]?.symbol, flash: store.flashes[t.mint])
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 26)
        .task { await store.loadNew(app: app) }
        .onDisappear { store.disconnect() }
    }
}

struct KingsSection: View {
    let stocks: [Stock]
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kings of the floor").h2Text()
                Text("The most traded token on each stock today").font(.sub).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 0) {
                ForEach(stocks) { s in
                    if let k = s.king {
                        Button { app.push(.token(k.mint)) } label: {
                            HStack(spacing: 12) {
                                Avatar(url: k.imageURL, symbol: k.symbol)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 7) {
                                        Text(k.symbol).font(.rowTitle).lineLimit(1)
                                        Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(Theme.amber)
                                    }
                                    Text("on \(s.symbol)").font(.sub).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(Fmt.big(k.vol24hUsd)).font(.rowPrice).monospacedDigit()
                                    Text("today").font(.rowChange).foregroundStyle(Theme.muted)
                                }
                            }
                            .padding(.vertical, 8).frame(minHeight: 64).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 26)
    }
}
