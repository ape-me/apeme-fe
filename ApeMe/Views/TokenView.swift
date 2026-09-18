import SwiftUI

struct TokenView: View {
    @State private var store: TokenStore

    init(mint: String) { _store = State(initialValue: TokenStore(mint: mint)) }

    var body: some View {
        Group {
            if let err = store.error, store.header == nil {
                ErrorBanner(message: err) { Task { await store.load() } }
            } else if let h = store.header {
                content(h)
            } else {
                ProgressView().tint(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .navigationTitle(store.header?.displaySymbol ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { LiveDot(on: store.live) }
        }
        .safeAreaInset(edge: .bottom) { apeButton }
        .task {
            store.connect()
            await store.load()
        }
        .onDisappear { store.disconnect() }
    }

    private func content(_ h: TokenHeader) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                header(h)
                stats(h)
                chart(h)
                tape(h)
            }
            .padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 12)
        }
    }

    private func header(_ h: TokenHeader) -> some View {
        HStack(alignment: .top, spacing: 12) {
            TokenImage(url: h.imageURL, seed: h.displaySymbol, size: 56, radius: 14)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(h.displaySymbol).font(.display(22)).lineLimit(1)
                    PhasePill(phase: h.phase, progress: h.progressPct)
                }
                Text(h.displayName).font(.body(13)).foregroundStyle(Theme.muted).lineLimit(1)
                HStack(spacing: 6) {
                    Text("on \(h.stock.symbol)").font(.mono(11, .semibold)).foregroundStyle(Theme.blue)
                    Text(Fmt.usd(h.stock.priceUsd)).font(.mono(11)).foregroundStyle(Theme.muted)
                    Text(Fmt.pct(h.stock.change24h)).font(.mono(11)).foregroundStyle(Theme.upDown(h.stock.change24h))
                    Text("· \(h.launchpad)").font(.mono(11)).foregroundStyle(Theme.faint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .card()
    }

    private func stats(_ h: TokenHeader) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.usd(h.priceUsd))
                    .font(.mono(30, .bold)).monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(store.flash.map { Theme.side($0.side) } ?? Theme.ink)
                    .animation(.easeOut(duration: 0.35), value: h.priceUsd)
                    .animation(.easeOut(duration: 0.6), value: store.flash?.stamp)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let p = h.priceQuote {
                        Text("\(Fmt.price(p)) \(h.stock.symbol)").font(.mono(11)).foregroundStyle(Theme.faint)
                    }
                    Ticking { now in
                        Text("last \(Fmt.age(h.lastTradeAt, now: now)) ago").font(.mono(11)).foregroundStyle(Theme.faint)
                    }
                }
            }
            HStack(spacing: 8) {
                StatCell(label: "MCAP", value: Fmt.compact(h.mcapUsd))
                StatCell(label: "VOL 24H", value: Fmt.compact(h.vol24hUsd))
                StatCell(label: "BUYS", value: Fmt.int(h.buys24h), color: Theme.green)
                StatCell(label: "SELLS", value: Fmt.int(h.sells24h), color: Theme.red)
                StatCell(label: "TAX", value: Fmt.tax(h.taxBps), color: h.taxBps > 0 ? Theme.amber : Theme.ink)
            }
            .animation(.easeOut(duration: 0.3), value: h.buys24h + h.sells24h)
            if h.phase == .curve, let p = h.progressPct {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CURVE PROGRESS").font(.mono(10)).foregroundStyle(Theme.faint)
                        Spacer()
                        Text(String(format: "%.1f%%", p)).font(.mono(11, .semibold)).foregroundStyle(Theme.amber)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(Theme.amber).frame(width: g.size.width * min(1, max(0, p / 100)))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(12)
        .card()
    }

    private func chart(_ h: TokenHeader) -> some View {
        VStack(spacing: 10) {
            HStack {
                Segmented(items: Timeframe.allCases, selected: store.tf, label: \.rawValue) { store.setTf($0) }
                if store.chartLoading { ProgressView().tint(Theme.muted).controlSize(.small) }
            }
            CandleChart(candles: store.candles, tf: store.tf,
                        mult: h.stock.priceUsd ?? 1, usd: h.stock.priceUsd != nil)
        }
        .padding(12)
        .card()
    }

    private func tape(_ h: TokenHeader) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRADES").font(.mono(11, .semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(store.trades.count)").font(.mono(11)).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            Divider().overlay(Theme.line)
            if store.trades.isEmpty {
                Text("No trades yet").font(.body(12)).foregroundStyle(Theme.faint).padding(20)
            } else {
                Ticking { now in
                    LazyVStack(spacing: 0) {
                        ForEach(store.trades) { t in
                            TradeRow(trade: t, symbol: h.displaySymbol, stockPrice: h.stock.priceUsd, now: now)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            Divider().overlay(Theme.line.opacity(0.6))
                        }
                    }
                    .animation(.easeOut(duration: 0.25), value: store.trades.first?.sig)
                }
            }
        }
        .card()
    }

    private var apeButton: some View {
        VStack(spacing: 6) {
            Button {} label: {
                HStack(spacing: 8) {
                    Text("🦍")
                    Text("APE").font(.display(20, .heavy))
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(LinearGradient(colors: [Theme.green, Color(hex: 0x3fcf7f)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(true)
            .opacity(0.45)
            Text("wallet coming").font(.mono(10)).foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
        .background(Theme.bg.opacity(0.96))
    }
}

struct TradeRow: View {
    let trade: Trade
    let symbol: String
    let stockPrice: Double?
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Text(trade.side == .buy ? "BUY" : "SELL")
                .font(.mono(11, .bold)).foregroundStyle(Theme.side(trade.side))
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Fmt.qty(trade.base)) \(symbol)").font(.mono(12, .semibold)).foregroundStyle(Theme.ink)
                Text(Fmt.short(trade.wallet)).font(.mono(10)).foregroundStyle(Theme.faint)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.usd(stockPrice.map { trade.quote * $0 })).font(.mono(12, .semibold)).foregroundStyle(Theme.ink)
                Text(Fmt.usd(trade.priceUsd)).font(.mono(10)).foregroundStyle(Theme.muted)
            }
            Text(Fmt.age(trade.ts, now: now))
                .font(.mono(10)).foregroundStyle(Theme.faint)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
