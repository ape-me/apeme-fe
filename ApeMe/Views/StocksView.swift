import SwiftUI

struct StocksView: View {
    @State private var store = StocksStore()

    var body: some View {
        Group {
            if let err = store.error, store.stocks.isEmpty {
                ErrorBanner(message: err) { Task { await store.load() } }
            } else if store.loading && store.stocks.isEmpty {
                ProgressView().tint(Theme.muted)
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .navigationTitle("Stocks")
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Ticking { now in
                    Text("\(store.stocks.count) · \(Fmt.age(store.asOf, now: now))")
                        .font(.mono(11)).foregroundStyle(Theme.faint)
                }
            }
        }
        .task {
            await store.load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                await store.load()
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.stocks) { stock in
                    NavigationLink(value: Route.floor(stock)) {
                        StockRow(stock: stock)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.line).padding(.leading, 62)
                }
            }
        }
        .refreshable { await store.load() }
    }
}

struct StockRow: View {
    let stock: Stock

    var body: some View {
        HStack(spacing: 12) {
            TokenImage(url: stock.logo.flatMap(URL.init), seed: stock.symbol, size: 38, radius: 19)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stock.symbol).font(.display(16))
                    if stock.marketOpen {
                        Circle().fill(Theme.green).frame(width: 5, height: 5)
                    }
                }
                Text(stock.name).font(.body(12)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.int(stock.memes))
                    .font(.mono(15, .semibold)).foregroundStyle(Theme.ink).monospacedDigit()
                Text("memes").font(.mono(10)).foregroundStyle(Theme.faint)
            }
            .frame(width: 64, alignment: .trailing)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.usd(stock.priceUsd))
                    .font(.mono(14, .semibold)).foregroundStyle(Theme.ink).monospacedDigit()
                Text(Fmt.pct(stock.change24h))
                    .font(.mono(11, .semibold)).foregroundStyle(Theme.upDown(stock.change24h)).monospacedDigit()
            }
            .frame(width: 84, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
