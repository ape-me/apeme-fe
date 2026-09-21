import SwiftUI

/// Up to 48 candles with a volume strip along the bottom. Drag to read OHLC.
struct CandleChart: View {
    let candles: [Candle]
    var onScrub: (Candle?) -> Void = { _ in }

    @State private var scrubIndex: Int? = nil

    var body: some View {
        if candles.isEmpty {
            EmptyState(title: "Live from now", subtitle: "No history before we started watching this floor.") {
                EmptyView()
            }
            .frame(height: 200)
        } else {
            let cs = Array(candles.suffix(48))
            GeometryReader { g in
            Canvas { ctx, size in
                let lo = cs.map(\.l).min()!, hi = cs.map(\.h).max()!
                let rg = (hi - lo) == 0 ? 1e-12 : (hi - lo)
                let pad = 4.0
                let cw = (size.width - 2 * pad) / CGFloat(cs.count)
                let bw = max(3, cw * 0.62)
                let vmax = cs.map(\.v).max() ?? 1
                func y(_ v: Double) -> CGFloat { pad + CGFloat(1 - (v - lo) / rg) * (size.height - 2 * pad - 18) }
                for (i, c) in cs.enumerated() {
                    let x = pad + CGFloat(i) * cw + cw / 2
                    let up = c.c >= c.o
                    let col = up ? Theme.green : Theme.red
                    var wick = Path()
                    wick.move(to: CGPoint(x: x, y: y(c.h)))
                    wick.addLine(to: CGPoint(x: x, y: y(c.l)))
                    ctx.stroke(wick, with: .color(col), lineWidth: 1)
                    let yo = y(c.o), yc = y(c.c)
                    let body = CGRect(x: x - bw / 2, y: min(yo, yc), width: bw, height: max(2, abs(yo - yc)))
                    ctx.fill(Path(roundedRect: body, cornerRadius: 1), with: .color(col))
                    let vh = vmax > 0 ? CGFloat(c.v / vmax) * 14 : 0
                    ctx.fill(Path(CGRect(x: x - bw / 2, y: size.height - vh, width: bw, height: vh)), with: .color(col.opacity(0.3)))
                    if scrubIndex == i {
                        var line = Path()
                        line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(line, with: .color(Theme.muted), lineWidth: 1)
                    }
                }
            }
            .frame(height: 200)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let i = min(cs.count - 1, max(0, Int(v.location.x / max(1, g.size.width) * CGFloat(cs.count))))
                        if i != scrubIndex { scrubIndex = i; onScrub(cs[i]) }
                    }
                    .onEnded { _ in scrubIndex = nil; onScrub(nil) }
            )
            }
            .frame(height: 200)
            .accessibilityLabel("Candle chart")
        }
    }
}
