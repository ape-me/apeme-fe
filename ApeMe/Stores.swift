import Foundation
import Observation

/// Screen 1. Sorted by meme count. Refreshes every 15s while on screen.
@Observable @MainActor
final class StocksStore {
    var stocks: [Stock] = []
    var asOf: Int?
    var loading = false
    var error: String?

    func load() async {
        if stocks.isEmpty { loading = true }
        defer { loading = false }
        do {
            let r = try await API.shared.stocks()
            stocks = r.stocks.sorted { $0.memes != $1.memes ? $0.memes > $1.memes : $0.symbol < $1.symbol }
            asOf = r.asOf
            error = nil
        } catch {
            if stocks.isEmpty { self.error = error.localizedDescription }
        }
    }
}

struct Flash: Equatable {
    let side: Side
    let stamp: Int
}

/// Screen 2. Cards for one stock, paged by cursor, bumped live from /ws/floor.
@Observable @MainActor
final class FloorStore {
    let stock: Stock
    private(set) var sort: Sort = .volume
    var tokens: [TokenCard] = []
    var next: String?
    var loading = false
    var loadingMore = false
    var error: String?
    var flashes: [String: Flash] = [:]
    var live = false

    private var socket: LiveSocket?
    private var listener: Task<Void, Never>?
    private var generation = 0
    private var stamp = 0

    init(stock: Stock) { self.stock = stock }

    func setSort(_ s: Sort) {
        guard s != sort else { return }
        sort = s
        Task { await load(reset: true) }
    }

    func load(reset: Bool) async {
        generation += 1
        let gen = generation
        if reset { loading = tokens.isEmpty; next = nil }
        defer { if gen == generation { loading = false } }
        do {
            let r = try await API.shared.tokens(stock: stock.mint, sort: sort)
            guard gen == generation else { return }
            tokens = r.tokens
            next = r.next
            error = nil
        } catch {
            guard gen == generation else { return }
            if tokens.isEmpty { self.error = error.localizedDescription }
        }
    }

    func loadMoreIfNeeded(current: TokenCard) {
        guard let next, !loadingMore, tokens.suffix(8).contains(where: { $0.mint == current.mint }) else { return }
        loadingMore = true
        let gen = generation
        Task {
            defer { loadingMore = false }
            do {
                let r = try await API.shared.tokens(stock: stock.mint, sort: sort, cursor: next)
                guard gen == generation else { return }
                let seen = Set(tokens.map(\.mint))
                tokens += r.tokens.filter { !seen.contains($0.mint) }
                self.next = r.next
            } catch { }
        }
    }

    func connect() {
        guard socket == nil else { return }
        let s = LiveSocket(path: "/ws/floor")
        socket = s
        listener = Task { [weak self] in
            for await ev in s.events {
                guard let self else { return }
                switch ev {
                case .opened: live = true
                case .closed: live = false
                case .trades(let ts): for t in ts { apply(t) }
                }
            }
        }
        s.start()
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        socket?.stop(); socket = nil
        live = false
    }

    /// The floor socket carries every token on every stock; only this stock's memes are on screen.
    private func apply(_ t: WsTrade) {
        guard let i = tokens.firstIndex(where: { $0.mint == t.mint }) else { return }
        var c = tokens[i]
        if let old = c.priceQuote, old > 0, let mc = c.mcapUsd {
            c.mcapUsd = mc * (t.priceQuote / old)
        }
        c.priceQuote = t.priceQuote
        c.priceUsd = t.priceUsd ?? stock.priceUsd.map { t.priceQuote * $0 }
        c.vol24hUsd += t.quote * (stock.priceUsd ?? 0)
        if t.side == .buy { c.buys24h += 1 } else { c.sells24h += 1 }
        c.lastTradeAt = t.ts
        tokens[i] = c
        stamp += 1
        flashes[t.mint] = Flash(side: t.side, stamp: stamp)
    }
}

/// Screen 3. Header, candles for one timeframe, tape. Live trades move the last candle and
/// prepend the tape; on reconnect the tape is refetched to fill any gap.
@Observable @MainActor
final class TokenStore {
    let mint: String
    var header: TokenHeader?
    var tf: Timeframe = .m1
    var candles: [Candle] = []
    var trades: [Trade] = []
    var loading = false
    var chartLoading = false
    var error: String?
    var live = false
    var flash: Flash?

    private var socket: LiveSocket?
    private var listener: Task<Void, Never>?
    private var stamp = 0
    private var chartGen = 0

    init(mint: String) { self.mint = mint }

    func load() async {
        loading = header == nil
        defer { loading = false }
        async let h = API.shared.token(mint)
        async let c = API.shared.candles(mint, tf: tf)
        async let t = API.shared.trades(mint)
        do {
            header = try await h
            error = nil
        } catch {
            if header == nil { self.error = error.localizedDescription }
        }
        if let r = try? await c { candles = r.candles }
        if let r = try? await t { merge(r.trades) }
    }

    func setTf(_ new: Timeframe) {
        guard new != tf else { return }
        tf = new
        chartGen += 1
        let gen = chartGen
        chartLoading = true
        Task {
            defer { if gen == chartGen { chartLoading = false } }
            if let r = try? await API.shared.candles(mint, tf: new), gen == chartGen {
                candles = r.candles
            }
        }
    }

    func connect() {
        guard socket == nil else { return }
        let s = LiveSocket(path: "/ws/\(mint)")
        socket = s
        listener = Task { [weak self] in
            for await ev in s.events {
                guard let self else { return }
                switch ev {
                case .opened(let reconnect):
                    live = true
                    if reconnect, let r = try? await API.shared.trades(mint) { merge(r.trades) }
                case .closed: live = false
                case .trades(let ts): for t in ts where t.mint == mint { apply(t.trade) }
                }
            }
        }
        s.start()
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        socket?.stop(); socket = nil
        live = false
    }

    private func merge(_ incoming: [Trade]) {
        var seen = Set(trades.map(\.sig))
        var all = trades
        for t in incoming where !seen.contains(t.sig) { all.append(t); seen.insert(t.sig) }
        all.sort { $0.ts != $1.ts ? $0.ts > $1.ts : $0.slot > $1.slot }
        trades = Array(all.prefix(200))
    }

    private func apply(_ t: Trade) {
        guard !trades.contains(where: { $0.sig == t.sig }) else { return }
        trades.insert(t, at: 0)
        if trades.count > 200 { trades.removeLast() }

        if var h = header {
            h.priceQuote = t.priceQuote
            h.priceUsd = t.priceUsd ?? h.stock.priceUsd.map { t.priceQuote * $0 }
            if let supply = h.supplyTokens, let p = h.priceUsd { h.mcapUsd = p * supply }
            h.vol24hUsd += t.quote * (h.stock.priceUsd ?? 0)
            if t.side == .buy { h.buys24h += 1 } else { h.sells24h += 1 }
            h.lastTradeAt = t.ts
            header = h
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
        stamp += 1
        flash = Flash(side: t.side, stamp: stamp)
    }
}
