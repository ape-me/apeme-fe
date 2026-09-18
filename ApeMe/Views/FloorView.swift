import SwiftUI

struct FloorView: View {
    @State private var store: FloorStore

    init(stock: Stock) { _store = State(initialValue: FloorStore(stock: stock)) }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.bg)
        .navigationTitle(store.stock.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { LiveDot(on: store.live) }
        }
        .task {
            store.connect()
            await store.load(reset: true)
        }
        .onDisappear { store.disconnect() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TokenImage(url: store.stock.logo.flatMap(URL.init), seed: store.stock.symbol, size: 28, radius: 14)
                Text(store.stock.name).font(.body(13)).foregroundStyle(Theme.muted)
                Spacer()
                Text(Fmt.usd(store.stock.priceUsd)).font(.mono(14, .semibold)).monospacedDigit()
                Text(Fmt.pct(store.stock.change24h))
                    .font(.mono(12, .semibold)).foregroundStyle(Theme.upDown(store.stock.change24h)).monospacedDigit()
                Text(store.stock.marketOpen ? "OPEN" : "CLOSED")
                    .font(.mono(9, .bold))
                    .foregroundStyle(store.stock.marketOpen ? Theme.green : Theme.faint)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Theme.surface2, in: Capsule())
            }
            Segmented(items: Sort.allCases, selected: store.sort, label: \.label) { store.setSort($0) }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 10)
        .background(Theme.bg)
    }

    @ViewBuilder private var content: some View {
        if let err = store.error, store.tokens.isEmpty {
            ErrorBanner(message: err) { Task { await store.load(reset: true) } }
            Spacer()
        } else if store.loading && store.tokens.isEmpty {
            Spacer(); ProgressView().tint(Theme.muted); Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.tokens) { token in
                        NavigationLink(value: Route.token(token.mint)) {
                            TokenCardView(token: token, flash: store.flashes[token.mint])
                        }
                        .buttonStyle(.plain)
                        .onAppear { store.loadMoreIfNeeded(current: token) }
                    }
                    if store.loadingMore {
                        ProgressView().tint(Theme.muted).padding()
                    } else if store.next == nil && !store.tokens.isEmpty {
                        Text("end of floor").font(.mono(11)).foregroundStyle(Theme.faint).padding()
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 24)
            }
            .refreshable { await store.load(reset: true) }
        }
    }
}

struct TokenCardView: View {
    let token: TokenCard
    let flash: Flash?

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TokenImage(url: token.imageURL, seed: token.displaySymbol)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(token.displaySymbol).font(.display(16)).lineLimit(1)
                        PhasePill(phase: token.phase, progress: token.progressPct)
                    }
                    Ticking { now in
                        Text("\(token.displayName) · \(token.launchpad) · \(Fmt.age(token.lastTradeAt, now: now))")
                            .font(.body(11)).foregroundStyle(Theme.faint).lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.usd(token.priceUsd))
                        .font(.mono(15, .semibold)).monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(flash.map { Theme.side($0.side) } ?? Theme.ink)
                        .animation(.easeOut(duration: 0.3), value: token.priceUsd)
                    if let ch = token.change24h {
                        Text(Fmt.pct(ch)).font(.mono(11, .semibold)).foregroundStyle(Theme.upDown(ch))
                    } else {
                        Text("tax \(Fmt.tax(token.taxBps))").font(.mono(11)).foregroundStyle(Theme.faint)
                    }
                }
            }
            HStack(spacing: 0) {
                stat("MCAP", Fmt.compact(token.mcapUsd))
                stat("VOL 24H", Fmt.compact(token.vol24hUsd))
                stat("BUYS", Fmt.int(token.buys24h), Theme.green)
                stat("SELLS", Fmt.int(token.sells24h), Theme.red)
                if token.change24h != nil {
                    stat("TAX", Fmt.tax(token.taxBps))
                }
            }
            if token.phase == .curve, let p = token.progressPct {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(Theme.amber).frame(width: g.size.width * min(1, max(0, p / 100)))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(12)
        .card()
        .overlay(FlashOverlay(flash: flash))
        .contentShape(Rectangle())
    }

    private func stat(_ l: String, _ v: String, _ color: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l).font(.mono(9)).foregroundStyle(Theme.faint)
            Text(v).font(.mono(13, .semibold)).foregroundStyle(color).monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: v)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
