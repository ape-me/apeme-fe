import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @State private var store = HomeStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                strip
                if !app.isApe { HeadlineStrip(items: store.headlines).padding(.top, 12) }
                HR().padding(.top, 8)
                tabs
                body_
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.ground)
        .task(id: app.mode) { await store.load(app: app) }
        .onDisappear { store.disconnect() }
        .refreshable { await store.load(app: app) }
    }

    /// Title left, mode switch right. Nothing about the wallet lives here — that's Portfolio.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(app.isApe ? "Floors" : "Home").h1Text()
            Spacer()
            ModeSwitch()
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    @ViewBuilder private var strip: some View {
        if app.isApe {
            Strip(items: store.ticker.filter { $0.kind == "meme" }.map { StripItem(id: $0.id, kind: .meme, label: $0.label, price: $0.price, change: $0.change24h) }).padding(.top, 10)
        } else {
            let items = (store.preipo + (store.movers?.mostTraded ?? []).prefix(4))
                .map { StripItem(id: $0.mint, kind: .stock, label: $0.symbol, price: $0.priceUsd, change: $0.change24h) }
            Strip(items: items).padding(.top, 10)
        }
    }

    @ViewBuilder private var tabs: some View {
        if app.isApe {
            UnderlineTabs(items: HomeStore.ApeTab.allCases, selected: store.apeTab, label: \.label) { store.apeTab = $0 }
                .padding(.horizontal, 20).padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
ScrollView(.horizontal) {
                UnderlineTabs(items: HomeStore.InvestTab.allCases, selected: store.investTab, label: \.label) { store.investTab = $0 }
                    .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.top, 6)
        }
    }

    @ViewBuilder private var body_: some View {
        if let err = store.error, store.preipo.isEmpty {
            EmptyState(title: err, subtitle: "Pull to retry from the Home tab.")
        } else if store.loading && store.preipo.isEmpty {
            VStack(spacing: 12) { Skeleton(height: 220); Skeleton(height: 64); Skeleton(height: 64) }
                .padding(.horizontal, 20).padding(.top, 26)
        } else if app.isApe {
            switch store.apeTab {
            case .preipo: PreIPOSection(stocks: store.preipoByHeat)
            case .new: NewLaunchesSection(store: store)
            case .kings: KingsSection(stocks: store.kings)
            }
        } else {
            switch store.investTab {
            case .preipo: PreIPOSection(stocks: store.preipo)
            case .movers: MoversSection(store: store)
            case .explore: ExploreSection(store: store)
            case .watch: WatchSection(store: store)
            case .news: NewsSection(store: store)
            }
        }
    }
}

/// `$1,141` with muted `.21`.
struct CentsText: View {
    let value: Double?
    var body: some View {
        if let c = Fmt.cents(value) {
            Text("\(Text(c.whole))\(Text(c.cents).foregroundStyle(Theme.muted).fontWeight(.medium))")
                .heroText()
        } else {
            Text("—").heroText()
        }
    }
}
