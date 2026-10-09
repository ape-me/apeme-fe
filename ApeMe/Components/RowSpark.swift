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
            // Curves through the midpoints: 24 hourly closes drawn as straight segments read as
            // noise at this size, and the shape of the day is what the row is for.
            let line = Path { p in
                p.move(to: pt(0))
                guard n > 2 else { if n == 2 { p.addLine(to: pt(1)) }; return }
                for i in 1..<n - 1 {
                    let a = pt(i), b = pt(i + 1)
                    p.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: a)
                }
                p.addLine(to: pt(n - 1))
            }
            ZStack {
                Path { p in
                    p.addPath(line)
                    p.addLine(to: CGPoint(x: g.size.width, y: g.size.height))
                    p.addLine(to: CGPoint(x: 0, y: g.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                if let b = baseline {
                    Path { p in p.move(to: CGPoint(x: 0, y: y(b))); p.addLine(to: CGPoint(x: g.size.width, y: y(b))) }
                        .stroke(tint.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                line.stroke(tint, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 60, height: 26)
    }

    /// Up if today ended above yesterday's close; the 24h change decides when there is no close.
    static func tint(points: [Double], baseline: Double?, change: Double?) -> Color {
        if let b = baseline, let last = points.last { return Theme.change(last - b) }
        return Theme.change(change)
    }
}
