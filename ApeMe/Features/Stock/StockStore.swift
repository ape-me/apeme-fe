import Foundation
import Observation

@Observable @MainActor
final class StockStore {
    let mint: String
    var stock: Stock?
    var range: HistoryRange = .d1
    var points: [LineChart.Point] = []
    var chartLoading = true
    var error: String?
    var scrub: LineChart.Point?

    private var rangeGen = 0

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

    /// No socket carries the stock's own price yet, so poll the edge every 5s while on screen.
    func poll(app: AppState) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { break }
            if let s = try? await API.shared.stock(mint, fresh: true) { stock = s; app.stocksByMint[mint] = s }
            if scrub == nil { await loadRange(fresh: true) }
        }
    }

    /// Change from the first point of the loaded range to the scrubbed point.
    var scrubChange: Double? {
        guard let s = scrub, let first = points.first, first.price > 0 else { return nil }
        return (s.price - first.price) / first.price * 100
    }
}
