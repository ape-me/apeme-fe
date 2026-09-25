import SwiftUI

/// One curated headline per stock, biggest movers first, under the price ticker.
struct HeadlineStrip: View {
    let items: [NewsItem]
    @Environment(\.openURL) private var openURL

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button { openArticle(item, openURL) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 5) {
                                    Text(item.symbol).foregroundStyle(Theme.ink)
                                    if let c = item.change24h { Text(Fmt.arrow(c, 1)).foregroundStyle(Theme.change(c)) }
                                    if let ts = item.publishedAt {
                                        Text("·").foregroundStyle(Theme.faint)
                                        Text(Fmt.ago(ts))
                                    }
                                }
                                .font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.muted)
                                Text(item.displayTitle)
                                    .font(.system(size: 12.5, weight: .semibold)).tracking(-0.1)
                                    .foregroundStyle(Theme.ink).lineSpacing(2).lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(width: 214, alignment: .topLeading)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Theme.surface, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(PressScale())
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// The News chip on Home: the user's stocks first, then the rest of the market.
struct NewsSection: View {
    let store: HomeStore
    @Environment(AppState.self) private var app
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let err = store.feedError, store.feed.isEmpty {
                ErrorBar(text: err).padding(.top, 20)
            } else if store.feed.isEmpty, !store.feedLoaded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest").h2Text()
                    Text(hasOwn ? "Your stocks first, then the rest of the market" : "Newest across every stock")
                        .font(.sub).foregroundStyle(Theme.muted)
                }
                .padding(.top, 20).padding(.bottom, 2)
                NewsListSkeleton()
            } else if store.feed.isEmpty {
                EmptyState(title: "No news yet.", subtitle: "Headlines land here within 20 minutes of publication.")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest").h2Text()
                    Text(hasOwn ? "Your stocks first, then the rest of the market" : "Newest across every stock")
                        .font(.sub).foregroundStyle(Theme.muted)
                }
                .padding(.top, 20).padding(.bottom, 2)
                if let lead = leadItem {
                    NewsLead(item: lead, open: { openArticle($0, openURL) }, openStock: { app.openStock($0) })
                    NewsList(items: store.feed.filter { $0.id != lead.id },
                             open: { openArticle($0, openURL) }, openStock: { app.openStock($0) })
                } else {
                    NewsList(items: store.feed,
                             open: { openArticle($0, openURL) }, openStock: { app.openStock($0) })
                }
            }
        }
        .padding(.horizontal, 20)
        .task(id: ownedKey) { await store.loadFeed(app: app) }
    }

    private var hasOwn: Bool {
        !app.watch.isEmpty || (app.wallet?.positions ?? []).contains { $0.kind == "stock" }
    }

    /// The banner, chosen from the user's own stocks first. Signed out, or watching nothing,
    /// any story with a picture may lead.
    private var leadItem: NewsItem? {
        let own = store.feed.prefix(store.ownedCount)
        if let mine = own.first(where: { $0.photoURL != nil }) { return mine }
        return store.ownedCount == 0 ? store.feed.first(where: { $0.photoURL != nil }) : nil
    }

    /// Changes the moment the wallet arrives, which is the signal to fetch the feed again.
    private var ownedKey: String {
        (app.watch + (app.wallet?.positions ?? []).filter { $0.kind == "stock" }.map(\.mint)).sorted().joined()
    }
}
