import SwiftUI
import Observation

@Observable @MainActor
final class TokenStore {
    enum Tab: String, CaseIterable, Identifiable {
        case trades, holders, about
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    enum Window: String, CaseIterable, Identifiable {
        case m5 = "5m", h1 = "1h", h24 = "24h"
        var id: String { rawValue }
    }

    let mint: String
    var token: TokenHeader?
    var error: String?
    var range: TokenRange = .live
    private(set) var tf: Timeframe = .m1
    var candles: [Candle] = []
    var chartLoading = true
    var showCandles = false
    var scrub: Candle?
    var scrubPoint: LineChart.Point?
    var tab: Tab = .trades
    var window: Window = .h24
    var trades: [Trade] = []
    var tradesLoading = true
    var status: LiveSocket.Status = .connecting
    var tapeFlash: [String: Flash] = [:]

    private var socket: LiveSocket?
    private var listener: Task<Void, Never>?
    private var chartGen = 0
    private var stamp = 0

    init(mint: String) { self.mint = mint }

    var quoteUsd: Double { token?.stock.quoteUsd ?? 0 }
    var stockSymbol: String { token?.stock.symbol ?? "" }

    func load(app: AppState) async {
        do {
            token = try await API.shared.token(mint)
            error = nil
        } catch {
            if token == nil { self.error = "Couldn't load this token." }
            return
        }
        async let c: () = loadChart()
        async let t: () = loadTrades()
        _ = await (c, t)
    }

    func setRange(_ r: TokenRange) {
        guard r != range else { return }
        range = r
        Task { await loadChart() }
    }

    func loadChart() async {
        chartGen += 1
        let g = chartGen
        let age = Int(Date.now.timeIntervalSince1970) - (token?.createdAt ?? 0)
        let spec = range.candles(age: age)
        tf = spec.tf
        chartLoading = true
        defer { if g == chartGen { chartLoading = false } }
        if let d = try? await API.shared.candles(mint, tf: spec.tf, limit: spec.limit), g == chartGen {
            candles = d.candles
        } else if g == chartGen {
            candles = []
        }
    }

    func loadTrades() async {
        tradesLoading = trades.isEmpty
        if let d = try? await API.shared.trades(mint, limit: 100) { merge(d.trades) }
        tradesLoading = false
    }

    /// LIVE = one point per trade, oldest → newest. Other ranges = candle closes. All in USD.
    var linePoints: [LineChart.Point] {
        if range == .live {
            return trades.reversed().map { LineChart.Point(t: $0.ts, price: $0.priceUsd ?? $0.priceQuote * quoteUsd, mark: nil) }
        }
        return candles.map { LineChart.Point(t: $0.t, price: $0.c * quoteUsd, mark: nil) }
    }

    /// Green when the visible series ends at or above where it started, else red.
    var direction: Color {
        let p = linePoints
        guard let f = p.first, let l = p.last else { return Theme.green }
        return l.price >= f.price ? Theme.green : Theme.red
    }

    func candle(at t: Int) -> Candle? { candles.first { $0.t == t } }

    func connect() {
        guard socket == nil else { return }
        let s = LiveSocket(room: mint)
        socket = s
        listener = Task { [weak self] in
            for await ev in s.events {
                guard let self else { return }
                switch ev {
                case .status(let st):
                    status = st
                    if st == .reconnecting { await loadTrades() }
                case .frames(let frames):
                    for case .trade(let t) in frames where t.mint == mint { apply(t.trade) }
                }
            }
        }
        s.start()
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        socket?.stop(); socket = nil
    }

    private func merge(_ incoming: [Trade]) {
        var seen = Set(trades.map(\.sig))
        var all = trades
        for t in incoming where seen.insert(t.sig).inserted { all.append(t) }
        all.sort { $0.ts != $1.ts ? $0.ts > $1.ts : $0.slot > $1.slot }
        trades = Array(all.prefix(100))
    }

    private func apply(_ t: Trade) {
        guard !trades.contains(where: { $0.sig == t.sig }) else { return }
        trades.insert(t, at: 0)
        if trades.count > 100 { trades.removeLast() }
        stamp += 1
        tapeFlash[t.sig] = Flash(side: t.side, stamp: stamp)

        if var h = token {
            h.priceQuote = t.priceQuote
            h.priceUsd = t.priceUsd ?? h.priceUsd
            if let supply = h.supplyTokens, let p = h.priceUsd { h.mcapUsd = p * supply }
            h.vol24hUsd = (h.vol24hUsd ?? 0) + t.quote * (h.stock.quoteUsd ?? 0)
            if t.side == .buy { h.buys24h = (h.buys24h ?? 0) + 1 } else { h.sells24h = (h.sells24h ?? 0) + 1 }
            h.lastTradeAt = t.ts
            token = h
        }

        let sec = tf.seconds
        let bucket = t.ts - t.ts % sec
        let p = t.priceQuote
        if let last = candles.last {
            if last.t == bucket {
                var c = last
                c.h = max(c.h, p); c.l = min(c.l, p); c.c = p; c.v += t.quote; c.n += 1
                candles[candles.count - 1] = c
            } else if bucket > last.t {
                candles.append(Candle(t: bucket, o: last.c, h: max(last.c, p), l: min(last.c, p), c: p, v: t.quote, n: 1))
            }
        } else {
            candles = [Candle(t: bucket, o: p, h: p, l: p, c: p, v: t.quote, n: 1)]
        }
    }
}
