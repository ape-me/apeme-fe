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
        // Four or five chips sharing the full width, so the row reads as the page's structure
        // rather than a few words huddled on the left.
        UnderlineTabs(items: HomeStore.InvestTab.ordered(watching: !app.watch.isEmpty), selected: store.investTab, fill: true, label: \.label) { store.investTab = $0 }
            .padding(.horizontal, 20)
            .padding(.top, 6)
    }

    @ViewBuilder private var body_: some View {
        if let err = store.error, store.preipo.isEmpty {
            EmptyState(title: err, subtitle: "Pull to retry from the Home tab.")
        } else if store.loading && store.preipo.isEmpty {
            // Explore's first screen: a heading, then the baskets grid.
            VStack(alignment: .leading, spacing: 14) {
                Skeleton(height: 22).frame(width: 120)
                LazyVGrid(columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in Skeleton(height: 150) }
                }
            }
            .padding(.horizontal, 20).padding(.top, 20)
        } else {
            switch store.investTab {
            case .explore:
                // One page to scroll, in the order a first-time visitor should meet things.
                VStack(alignment: .leading, spacing: 8) {
                    BasketsSection()
                    MoversSection(store: store)
                }
            case .movers: MoversSection(store: store)
            case .preipo: PreIPOSection(stocks: store.preipo)
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
