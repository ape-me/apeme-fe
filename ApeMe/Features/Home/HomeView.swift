import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @State private var store = HomeStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                strip.padding(.top, 8)
                // The headline strip used to sit here. Two horizontal scrollers stacked above
                // the tabs meant four things to swipe before a single price was legible, and
                // News is already a tab of its own.
                HR().padding(.top, 14)
                tabs
                body_
            }
            .padding(.bottom, 24)
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
        .background(Theme.ground)
        .task {
            await store.load(app: app)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                if Task.isCancelled { break }
                await store.refreshPrices(app: app)
            }
        }
        .refreshable { await store.load(app: app) }
    }

    /// No title: the tab bar already says which screen this is, and the market should be the
    /// first thing on it.
    private var strip: some View {
        let items = (store.preipo + (store.movers?.mostTraded ?? []).prefix(4))
            .map { StripItem(id: $0.mint, label: $0.symbol, price: $0.priceUsd, change: $0.change24h) }
        return Strip(items: items).padding(.top, 10)
    }

    private var tabs: some View {
        ScrollView(.horizontal) {
            UnderlineTabs(items: HomeStore.InvestTab.ordered(watching: !app.watch.isEmpty), selected: store.investTab, label: \.label) { store.investTab = $0 }
                .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 6)
    }

    @ViewBuilder private var body_: some View {
        if let err = store.error, store.preipo.isEmpty {
            EmptyState(title: err, subtitle: "Pull to retry from the Home tab.")
        } else if store.loading && store.preipo.isEmpty {
            VStack(spacing: 12) { Skeleton(height: 220); Skeleton(height: 64); Skeleton(height: 64) }
                .padding(.horizontal, 20).padding(.top, 26)
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
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: value)
        } else {
            Text("—").heroText()
        }
    }
}
