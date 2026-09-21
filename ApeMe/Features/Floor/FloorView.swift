import SwiftUI

/// The stock's memes. Ape mode only: green, King pinned, live flashes.
struct FloorView: View {
    @Environment(AppState.self) private var app
    @State private var store: FloorStore

    init(mint: String) { _store = State(initialValue: FloorStore(mint: mint)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BackButton()
                Spacer()
                StatusChip(text: store.status.rawValue, live: store.status == .live)
            }
            .padding(.horizontal, 12).padding(.top, 6).frame(minHeight: 56)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let s = store.stock { header(s) }
                    if let err = store.error, store.tokens.isEmpty {
                        ErrorBar(text: err)
                    } else if store.loading && store.tokens.isEmpty {
                        VStack(spacing: 12) { Skeleton(height: 120); Skeleton(height: 64) }.padding(20)
                    } else {
                        actions
                        kingCard
                        HR().padding(.top, 24)
                        sortPills
                        list
                        StatusChip(text: app.online ? "Live" : "Snapshot", live: app.online)
                            .padding(.horizontal, 20).padding(.top, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .environment(\.skin, Skin(mode: .ape))
        .task {
            store.connect(app: app)
            await store.load(app: app)
        }
        .onDisappear { store.disconnect() }
    }

    private func header(_ s: Stock) -> some View {
        HStack(spacing: 12) {
            Logo(url: s.logoURL, symbol: s.symbol, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.symbol) floor").h2Text()
                Text("\(Fmt.usd(s.priceUsd)) · \(Text(Fmt.arrow(s.change24h)).foregroundStyle(Theme.change(s.change24h))) · \(s.memes) memes · \(Fmt.big(s.memeVol24hUsd)) today")
                    .font(.sub).monospacedDigit().foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .padding(.horizontal, 20).padding(.top, 4)
    }

    private var actions: some View {
        ActionRow(items: [
            ActionItem(id: "ape", label: "Ape king", symbol: "plus", accent: true) { apeKing() },
            ActionItem(id: "buy", label: "Buy stock", symbol: "arrow.left.arrow.right") { if let s = store.stock { app.sheet = .buyStock(s) } },
            ActionItem(id: "launch", label: "Launch", symbol: "paperplane") { app.show("Launch flow lands with the Tuesday endpoint") },
            ActionItem(id: "share", label: "Share", symbol: "square.and.arrow.up") { app.copy(store.mint) },
        ])
        .padding(.horizontal, 20).padding(.top, 18)
    }

    private func apeKing() {
        guard let k = store.king else { app.show("No king yet on this floor"); return }
        Task {
            do {
                let t = try await API.shared.token(k.mint)
                app.sheet = .apeToken(t.card, t.stock)
            } catch { app.show("Could not load a quote") }
        }
    }

    @ViewBuilder private var kingCard: some View {
        if let k = store.king {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill").font(.system(size: 12))
                    Text("King of the floor")
                }
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.amber)
                Button { app.push(.token(k.mint)) } label: {
                    HStack(spacing: 12) {
                        Avatar(url: k.imageURL, symbol: k.symbol, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.symbol).h2Text().lineLimit(1)
                            Text("\(Fmt.big(k.vol24hUsd)) traded today" + (k.mcapUsd.map { " · MC \(Fmt.big($0))" } ?? ""))
                                .font(.sub).monospacedDigit().foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if let ch = k.change24h {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Fmt.arrow(ch, 1)).font(.rowPrice).monospacedDigit().foregroundStyle(Theme.change(ch))
                                Text("24h").font(.sub).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .padding(18)
                    .background(Theme.surface, in: .rect(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 24)
        }
    }

    private var sortPills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(FloorSort.allCases) { s in
                    Pill(label: s.label, on: store.sort == s, size: .small) { store.setSort(s, app: app) }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 18)
    }

    @ViewBuilder private var list: some View {
        if store.tokens.isEmpty {
            EmptyState(title: "No tokens yet", subtitle: "Nobody has launched on this floor.")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(store.tokens) { t in
                    TokenRow(token: t, isKing: store.isKing(t), flash: store.flashes[t.mint])
                        .onAppear { store.loadMoreIfNeeded(t) }
                }
                if store.loadingMore { ProgressView().tint(Theme.muted).padding() }
            }
            .padding(.horizontal, 20).padding(.top, 6)
        }
    }
}
