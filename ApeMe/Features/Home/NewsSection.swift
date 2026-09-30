import SwiftUI

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
                markets
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

    /// Macro sits above the company news because it is the frame for it: rates and tariffs move
    /// every name below. Kept to three so it stays context rather than becoming the page.
    @ViewBuilder private var markets: some View {
        if !store.marketFeed.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("Markets").h2Text()
                Text("What's moving everything").font(.sub).foregroundStyle(Theme.muted)
            }
            .padding(.top, 20).padding(.bottom, 2)
            NewsList(items: Array(store.marketFeed.prefix(3)),
                     open: { openArticle($0, openURL) }, openStock: { app.openStock($0) })
        }
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
