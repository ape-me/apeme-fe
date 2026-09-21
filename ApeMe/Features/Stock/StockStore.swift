import SwiftUI
import Observation

@Observable @MainActor
final class StockStore {
    let mint: String
    var stock: Stock?
    var range: HistoryRange = .live
    var longRange: HistoryRange = .w1
    var points: [LineChart.Point] = []
    var chartLoading = true
    var error: String?
    var scrub: LineChart.Point?
    var status: LiveSocket.Status = .connecting

    private var rangeGen = 0
    private var socket: LiveSocket?
    private var listener: Task<Void, Never>?

    init(mint: String) { self.mint = mint }

    func load(app: AppState) async {
        if stock == nil { stock = app.stocksByMint[mint] }
        do {
            let s = try await API.shared.stock(mint)
            stock = s
            app.stocksByMint[mint] = s
        } catch {
            if stock == nil { self.error = "Couldn't load this stock." }
        }
        await loadRange()
    }

    func setRange(_ r: HistoryRange) {
        guard r != range else { return }
        range = r
        Task { await loadRange() }
    }

    func loadRange(fresh: Bool = false) async {
        rangeGen += 1
        let gen = rangeGen
        chartLoading = points.isEmpty
        defer { if gen == rangeGen { chartLoading = false } }
        do {
            let h = try await API.shared.history(mint, range: range, fresh: fresh)
            guard gen == rangeGen else { return }
            // The chart shows what people pay; fair value lives in the bar below, not on the line.
            points = h.points.compactMap { p in p.price.map { LineChart.Point(t: p.t, price: $0, mark: nil) } }
        } catch {
            guard gen == rangeGen, !fresh else { return }
            points = []
        }
    }

    /// `stock:<mint>` pushes `{t:"price"}` when the price moves; the chart gets a point appended.
    func connect(app: AppState) {
        guard socket == nil else { return }
        let s = LiveSocket(room: "stock:\(mint)")
        socket = s
        listener = Task { [weak self] in
            for await ev in s.events {
                guard let self else { return }
                switch ev {
                case .status(let st): status = st
                case .frames(let frames):
                    for case .price(let p) in frames where p.mint == mint { apply(p, app: app) }
                }
            }
        }
        s.start()
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        socket?.stop(); socket = nil
    }

    /// Re-sync the series with the server every 30s so client-appended points never drift.
    func resync() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            if Task.isCancelled { break }
            if scrub == nil { await loadRange(fresh: true) }
        }
    }

    private func apply(_ p: WsPrice, app: AppState) {
        guard var s = stock, let price = p.priceUsd else { return }
        s.priceUsd = price
        if let c = p.change24h { s.change24h = c }
        if let m = p.markUsd { s.markUsd = m; s.premiumPct = (price - m) / m * 100 }
        stock = s
        app.stocksByMint[mint] = s
        guard scrub == nil else { return }
        let bucket = p.ts - p.ts % range.bucket
        if let last = points.last, last.t >= bucket {
            points[points.count - 1] = LineChart.Point(t: last.t, price: price, mark: nil)
        } else {
            points.append(LineChart.Point(t: bucket, price: price, mark: nil))
        }
    }

    /// Green when the visible series ends at or above where it started, else red.
    var direction: Color {
        guard let f = points.first, let l = points.last else { return Theme.green }
        return l.price >= f.price ? Theme.green : Theme.red
    }

    /// Change from the first point of the loaded range to the scrubbed point.
    var scrubChange: Double? {
        guard let s = scrub, let first = points.first, first.price > 0 else { return nil }
        return (s.price - first.price) / first.price * 100
    }
}
