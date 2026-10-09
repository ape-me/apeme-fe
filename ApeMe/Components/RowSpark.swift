import SwiftUI

/// The last day as a line in a list row: a wash under it, a dashed line where yesterday's
/// price sits, green or red by which side of that line today ended on. No axes, no touch.
struct RowSpark: View {
    let points: [Double]
    var baseline: Double? = nil
    let tint: Color

    var body: some View {
        GeometryReader { g in
            let all = points + (baseline.map { [$0] } ?? [])
            let lo = all.min() ?? 0, hi = all.max() ?? 1
            // A flat day still needs a span, or every point lands on one pixel.
            let span = max(hi - lo, max(abs(hi), 1e-9) * 0.002)
            let inset: CGFloat = 1.5
            let y: (Double) -> CGFloat = { v in inset + (g.size.height - 2 * inset) * (1 - CGFloat((v - lo) / span)) }
            let n = points.count
            let pt: (Int) -> CGPoint = { i in CGPoint(x: g.size.width * CGFloat(i) / CGFloat(max(n - 1, 1)), y: y(points[i])) }
            let line = Path { p in
                p.move(to: pt(0))
                for i in 1..<n { p.addLine(to: pt(i)) }
            }
            ZStack {
                Path { p in
                    p.addPath(line)
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                    p.addLine(to: CGPoint(x: 0, y: g.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                if let b = baseline {
                    Path { p in p.move(to: CGPoint(x: 0, y: y(b))); p.addLine(to: CGPoint(x: g.size.width, y: y(b))) }
                        .stroke(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
                line.stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 60, height: 24)
    }

    /// Up if today ended above yesterday's close; the 24h change decides when there is no close.
    static func tint(points: [Double], baseline: Double?, change: Double?) -> Color {
        if let b = baseline, let last = points.last { return Theme.change(last - b) }
        return Theme.change(change)
    }
}
