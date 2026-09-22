import SwiftUI

/// One curated headline per stock, biggest movers first, under the price ticker.
struct HeadlineStrip: View {
    let items: [NewsItem]
    @Environment(AppState.self) private var app

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button { Haptic.light(); app.sheet = .article(item) } label: {
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
                                Text(item.title)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let err = store.feedError, store.feed.isEmpty {
                ErrorBar(text: err).padding(.top, 20)
            } else if store.feed.isEmpty, store.feedLoading {
                VStack(spacing: 12) { ForEach(0..<4, id: \.self) { _ in Skeleton(height: 66) } }.padding(.top, 20)
            } else if store.feed.isEmpty {
                EmptyState(title: "No news yet.", subtitle: "Headlines land here within 20 minutes of publication.")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latest").h2Text()
                    Text(hasOwn ? "Your stocks first, then the rest of the market" : "Newest across every stock")
                        .font(.sub).foregroundStyle(Theme.muted)
                }
                .padding(.top, 20).padding(.bottom, 2)
                NewsList(items: store.feed,
                         open: { app.sheet = .article($0) },
                         openStock: { app.openStock($0) })
            }
        }
        .padding(.horizontal, 20)
        .task { await store.loadFeed(app: app) }
    }

    private var hasOwn: Bool {
        !app.watch.isEmpty || (app.wallet?.positions ?? []).contains { $0.kind == "stock" }
    }
}
