import SwiftUI

// MARK: - Home chip

/// The list, as cards. Everything on it is what /baskets returned.
struct BasketsSection: View {
    @Environment(AppState.self) private var app
    @State private var store = BasketsStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Baskets").h2Text()
                Text("A whole theme in one tap, equal weight").font(.sub).foregroundStyle(Theme.muted)
            }
            if let err = store.error, store.baskets.isEmpty {
                ErrorBar(text: err).padding(.horizontal, -20)
            } else if store.baskets.isEmpty {
                VStack(spacing: 10) { Skeleton(height: 92); Skeleton(height: 92); Skeleton(height: 92) }
            } else {
                VStack(spacing: 10) {
                    ForEach(store.baskets) { b in BasketCard(basket: b) { app.push(.basket(b.id)) } }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20)
        .task { await store.load() }
    }
}

struct BasketCard: View {
    let basket: Basket
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                LogoStack(urls: basket.logoURLs)
                VStack(alignment: .leading, spacing: 3) {
                    Text(basket.name).font(.rowTitle).tracking(-0.2)
                    if let t = basket.tagline { Text(t).font(.sub).foregroundStyle(Theme.muted).lineLimit(1) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.pct(basket.return1y, 1)).font(.rowPrice).monospacedDigit()
                        .foregroundStyle(basket.return1y == nil ? Theme.muted : Theme.change(basket.return1y))
                    Text(basket.returnLabel ?? "1Y").font(.sub).foregroundStyle(Theme.faint)
                }
            }
            .padding(14)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
            .contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }
}

/// Up to five logos overlapping, the way a basket of things reads at a glance.
struct LogoStack: View {
    let urls: [URL]
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(Array(urls.prefix(5).enumerated()), id: \.offset) { _, u in
                RemoteImage(url: u, fallback: "")
                    .frame(width: size, height: size)
                    .clipShape(.circle)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
            }
        }
        .frame(width: size + CGFloat(max(0, min(urls.count, 5) - 1)) * size * 0.68, alignment: .leading)
    }
}

// MARK: - Basket page

struct BasketView: View {
    let id: String
    @Environment(AppState.self) private var app
    @State private var store = BasketsStore()
    @State private var amount = ""

    private var d: BasketDetail? { store.detail }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BackButton(); Text(d?.name ?? "Basket").h2Text(); Spacer() }
                .padding(.horizontal, 12).padding(.top, 6).frame(height: 56)
            ScrollView {
                if let d {
                    VStack(alignment: .leading, spacing: 22) {
                        header(d)
                        chart(d)
                        if let desc = d.description {
                            Text(desc).font(.body15).foregroundStyle(Theme.muted).lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        extremes(d)
                        stocks(d)
                        rebalance
                        Text("1% Stonks247 fee on each swap. Minimum \(Fmt.cash(d.minUsd ?? 10)).")
                            .font(.sub).foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 120)
                } else if let err = store.error {
                    ErrorBar(text: err)
                } else {
                    VStack(spacing: 12) { Skeleton(height: 60); Skeleton(height: 200); Skeleton(height: 64) }
                        .padding(.horizontal, 20).padding(.top, 20)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .safeAreaInset(edge: .bottom) { if let d { invest(d) } }
        .task { await store.load(id) }
    }

    private func header(_ d: BasketDetail) -> some View {
        HStack(alignment: .top, spacing: 14) {
            LogoStack(urls: (d.logos ?? []).compactMap(URL.init(string:)), size: 36)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.pct(d.return1y, 1))
                    .font(.system(size: 30, weight: .semibold)).tracking(-0.8).monospacedDigit()
                    .foregroundStyle(d.return1y == nil ? Theme.muted : Theme.change(d.return1y))
                Text(d.returnLabel ?? "1Y").font(.sub).foregroundStyle(Theme.muted)
            }
        }
    }

    @ViewBuilder private func chart(_ d: BasketDetail) -> some View {
        if let c = d.chart, c.points.count > 1 {
            LineChart(points: c.points.map { .init(t: $0.t, price: $0.value, mark: nil) },
                      reference: 100, tint: Theme.change(d.return1y), drawKey: d.id, height: 180)
        }
    }

    @ViewBuilder private func extremes(_ d: BasketDetail) -> some View {
        if d.best != nil || d.worst != nil {
            KCard {
                if let b = d.best { KV("Best") { Text("\(b.symbol)  \(Fmt.pct(b.return1y, 1))").monospacedDigit().foregroundStyle(Theme.change(b.return1y)) } }
                if let w = d.worst { KV("Worst") { Text("\(w.symbol)  \(Fmt.pct(w.return1y, 1))").monospacedDigit().foregroundStyle(Theme.change(w.return1y)) } }
            }
        }
    }

    private func stocks(_ d: BasketDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("\(d.stocks.count) stocks, equal weight")
            VStack(spacing: 0) {
                ForEach(d.stocks) { leg in
                    HStack(spacing: 12) {
                        StockRow(stock: leg.stock)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(String(format: "%.1f%%", leg.weight ?? 0)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                            Text(Fmt.pct(leg.return1y, 0)).font(.sub).monospacedDigit().foregroundStyle(Theme.change(leg.return1y))
                        }
                    }
                }
            }
        }
    }

    /// Demo eye-candy: there is nothing behind it yet, and the toggle says so.
    private var rebalance: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rebalance").font(.system(size: 15, weight: .semibold))
                Text("Keep every stock at equal weight").font(.sub).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("COMING SOON").font(.system(size: 9, weight: .bold)).tracking(0.4).foregroundStyle(Theme.amber)
                .padding(.horizontal, 6).frame(height: 17).background(Theme.amberT, in: .rect(cornerRadius: 5))
            Toggle("", isOn: .constant(false)).labelsHidden().disabled(true)
        }
        .padding(14).background(Theme.surface, in: .rect(cornerRadius: 14))
    }

    private var usd: Double { Double(amount) ?? 0 }
    private var minUsd: Double { d?.minUsd ?? 10 }

    private func invest(_ d: BasketDetail) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach([10, 25, 50, 100], id: \.self) { v in
                    Pill(label: "$\(v)", on: usd == Double(v), size: .small, wide: true) { amount = "\(v)" }
                }
            }
            HStack(spacing: 10) {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad).font(.system(size: 20, weight: .semibold)).monospacedDigit()
                    .padding(.horizontal, 14).frame(height: 52).background(Theme.surface, in: .capsule)
                BigButton(label: !d.canTrade ? "Market closed" : usd < minUsd ? "Min \(Fmt.cash(minUsd))" : "Invest \(Fmt.cash(usd))",
                          style: d.canTrade && usd >= minUsd ? .buy : .off) {
                    guard d.canTrade, usd >= minUsd else { return }
                    guard app.walletAddress != nil else { app.sheet = .login; return }
                    Haptic.medium(); app.sheet = .basket(d, amountUsd: usd)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12).background(Theme.ground)
    }
}
