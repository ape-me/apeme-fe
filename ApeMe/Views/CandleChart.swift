import SwiftUI
import Charts

/// Candles + volume, scrollable, pinned to the newest bar. Prices are shown in USD
/// (`quote × stock.priceUsd`) when the stock has a price, else in stock units.
struct CandleChart: View {
    let candles: [Candle]
    let tf: Timeframe
    let mult: Double
    let usd: Bool

    @State private var scrollX: Date = .distantPast
    private let visibleBars = 60

    var body: some View {
        if candles.isEmpty {
            VStack(spacing: 6) {
                Text("Live from now").font(.display(15)).foregroundStyle(Theme.muted)
                Text("No chart history for this token yet. Trades will draw it.")
                    .font(.body(12)).foregroundStyle(Theme.faint).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).frame(height: 260)
        } else {
            VStack(spacing: 2) {
                priceChart.frame(height: 220)
                volumeChart.frame(height: 48)
            }
            .onAppear { snapToEnd() }
            .onChange(of: candles.count) { snapToEnd() }
            .onChange(of: tf) { snapToEnd() }
        }
    }

    private var visibleLength: Int { tf.seconds * visibleBars }

    private func snapToEnd() {
        guard let last = candles.last else { return }
        scrollX = date(last.t - visibleLength + tf.seconds)
    }

    private func date(_ t: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(t)) }

    /// Bars inside the scrolled window, for a y-range that fits what's on screen.
    private var window: [Candle] {
        let lo = Int(scrollX.timeIntervalSince1970) - tf.seconds
        let hi = lo + visibleLength + 2 * tf.seconds
        let w = candles.filter { $0.t >= lo && $0.t <= hi }
        return w.isEmpty ? Array(candles.suffix(visibleBars)) : w
    }

    private var yDomain: ClosedRange<Double> {
        let w = window
        let lo = (w.map(\.l).min() ?? 0) * mult
        let hi = (w.map(\.h).max() ?? 1) * mult
        let pad = max((hi - lo) * 0.08, hi * 0.002)
        return (lo - pad)...(hi + pad)
    }

    private var priceChart: some View {
        let dom = yDomain
        let minBody = (dom.upperBound - dom.lowerBound) * 0.004
        return Chart(candles, id: \.t) { c in
            let up = c.c >= c.o
            let color = up ? Theme.green : Theme.red
            let lo = min(c.o, c.c) * mult
            let hi = max(max(c.o, c.c) * mult, lo + minBody)
            RuleMark(x: .value("t", date(c.t + tf.seconds / 2)),
                     yStart: .value("l", c.l * mult), yEnd: .value("h", c.h * mult))
                .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 1))
            RectangleMark(xStart: .value("s", date(c.t + tf.seconds / 8)),
                          xEnd: .value("e", date(c.t + tf.seconds * 7 / 8)),
                          yStart: .value("o", lo), yEnd: .value("c", hi))
                .foregroundStyle(color)
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleLength)
        .chartScrollPosition(x: $scrollX)
        .chartYScale(domain: dom)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { v in
                AxisGridLine().foregroundStyle(Theme.line)
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(usd ? Fmt.usd(d) : Fmt.price(d)).font(.mono(9)).foregroundStyle(Theme.faint)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.line.opacity(0.6))
                AxisValueLabel(format: tf.seconds >= 86400 ? .dateTime.month().day() : .dateTime.hour().minute())
                    .font(.mono(9)).foregroundStyle(Theme.faint)
            }
        }
    }

    private var volumeChart: some View {
        Chart(candles, id: \.t) { c in
            BarMark(xStart: .value("s", date(c.t + tf.seconds / 8)),
                    xEnd: .value("e", date(c.t + tf.seconds * 7 / 8)),
                    y: .value("v", c.v))
                .foregroundStyle((c.c >= c.o ? Theme.green : Theme.red).opacity(0.5))
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleLength)
        .chartScrollPosition(x: $scrollX)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { v in
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(Fmt.qty(d)).font(.mono(8)).foregroundStyle(Theme.faint)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }
}
