import SwiftUI

/// Accent line, halftone dot fill, no axes. Dashed amber = fair value. Drag to scrub.
struct LineChart: View {
    struct Point: Hashable { let t: Int; let price: Double; let mark: Double? }

    let points: [Point]
    var reference: Double? = nil
    /// Overrides the accent, e.g. green/red by direction on the token page.
    var tint: Color? = nil
    var emptyTitle = "No history for this range"
    var emptySubtitle = "Try another timeframe."
    var onScrub: (Point?) -> Void = { _ in }

    @Environment(\.skin) private var skin
    @State private var scrubIndex: Int? = nil

    private var color: Color { tint ?? skin.accent }

    var body: some View {
        if points.isEmpty {
            EmptyState(title: emptyTitle, subtitle: emptySubtitle)
                .frame(height: 200)
        } else {
            GeometryReader { g in
                // Draw whatever exists across the full width; one point becomes a flat line.
                let series = points.count == 1 ? [points[0], Point(t: points[0].t + 1, price: points[0].price, mark: nil)] : points
                let geo = Geometry(points: series, reference: reference, size: g.size)
                ZStack(alignment: .topLeading) {
                    AreaShape(geo: geo)
                        .fill(ImagePaint(image: Self.dot(color), scale: 1))
                        .mask { LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom) }
                    if let mark = geo.markPath {
                        mark.stroke(Theme.amber, style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                    }
                    geo.linePath.stroke(color, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    Circle().fill(color).frame(width: 8, height: 8)
                        .position(geo.xy(series.count - 1))
                    if geo.refFar, let ref = reference {
                        farTag(ref, below: ref < geo.pmin)
                    }
                    if let i = scrubIndex {
                        scrub(geo, i)
                    }
                }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let i = min(points.count - 1, geo.nearest(x: v.location.x))
                            if i != scrubIndex { scrubIndex = i; onScrub(points[i]) }
                        }
                        .onEnded { _ in scrubIndex = nil; onScrub(nil) }
                )
            }
            .frame(height: 200)
            .accessibilityLabel("Price chart")
        }
    }

    private func scrub(_ geo: Geometry, _ i: Int) -> some View {
        let p = geo.xy(i)
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.muted).frame(width: 1).position(x: p.x, y: geo.size.height / 2)
                .frame(height: geo.size.height)
            Circle().fill(color).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Theme.ground, lineWidth: 2))
                .position(p)
            Text(Fmt.dateTime(points[i].t))
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                .fixedSize()
                .position(x: min(geo.size.width * 0.88, max(geo.size.width * 0.12, p.x)), y: 4)
        }
    }

    private func farTag(_ ref: Double, below: Bool) -> some View {
        HStack(spacing: 6) {
            Rectangle().stroke(Theme.amber, style: StrokeStyle(lineWidth: 2, dash: [3, 3])).frame(width: 10, height: 0)
            Text("Fair value \(Fmt.usd(ref)) \(below ? "↓ below" : "↑ above")")
        }
        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.amber)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Theme.amberT, in: .capsule)
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .bottomLeading : .topLeading)
        .padding(.vertical, 8)
    }

    /// 4×4 halftone tile in the accent color.
    private static func dot(_ color: Color) -> Image {
        Image(size: CGSize(width: 4, height: 4)) { ctx in
            ctx.fill(Path(ellipseIn: CGRect(x: 1, y: 1, width: 2, height: 2)), with: .color(color))
        }
    }

    /// Pixel mapping, mirroring the prototype's `lineChart`.
    struct Geometry {
        let points: [Point]
        let size: CGSize
        let pmin: Double
        let refFar: Bool
        private let lo: Double, hi: Double, t0: Int, t1: Int
        private let marks: [Point]
        private let currentOnly: Bool
        private let reference: Double?

        init(points: [Point], reference: Double?, size: CGSize) {
            self.points = points
            self.size = size
            let prices = points.map(\.price)
            pmin = prices.min() ?? 0
            let pmax = prices.max() ?? 1
            let prg = (pmax - pmin) == 0 ? pmax * 0.01 : (pmax - pmin)
            var marks = points.filter { $0.mark != nil }
            var currentOnly = marks.count < 2 && reference != nil
            let refVal = currentOnly ? reference : marks.last?.mark
            let lowLimit = pmin - prg * 1.5, highLimit = pmax + prg * 1.5
            let far = refVal.map { $0 < lowLimit || $0 > highLimit } ?? false
            if far { marks = []; currentOnly = false }
            refFar = far
            var vals = prices + marks.compactMap(\.mark)
            if currentOnly, let reference { vals.append(reference) }
            let mn = vals.min() ?? 0, mx = vals.max() ?? 1
            let rg = (mx - mn) == 0 ? mx * 0.01 : (mx - mn)
            lo = mn - rg * 0.1; hi = mx + rg * 0.1
            t0 = points.first!.t; t1 = points.last!.t
            self.marks = marks
            self.currentOnly = currentOnly
            self.reference = reference
        }

        func x(_ t: Int) -> CGFloat { CGFloat(Double(t - t0) / Double(max(1, t1 - t0))) * size.width }
        func y(_ v: Double) -> CGFloat {
            let top = 10.0, bottom = size.height - 6
            return bottom - CGFloat((v - lo) / (hi - lo)) * (bottom - top)
        }
        func xy(_ i: Int) -> CGPoint { CGPoint(x: x(points[i].t), y: y(points[i].price)) }

        var linePath: Path {
            var p = Path()
            for (i, pt) in points.enumerated() {
                let c = CGPoint(x: x(pt.t), y: y(pt.price))
                if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
            }
            return p
        }
        var markPath: Path? {
            if marks.count > 1 {
                var p = Path()
                for (i, pt) in marks.enumerated() {
                    let c = CGPoint(x: x(pt.t), y: y(pt.mark!))
                    if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
                }
                return p
            }
            if currentOnly, let reference {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y(reference)))
                p.addLine(to: CGPoint(x: size.width, y: y(reference)))
                return p
            }
            return nil
        }
        func nearest(x px: CGFloat) -> Int {
            let clamped = min(max(0, px), size.width)
            let t = Double(t0) + Double(clamped / size.width) * Double(t1 - t0)
            var i = 0
            while i < points.count - 1 && Double(points[i + 1].t) <= t { i += 1 }
            if i < points.count - 1 && abs(Double(points[i + 1].t) - t) < abs(Double(points[i].t) - t) { i += 1 }
            return i
        }
    }

    struct AreaShape: Shape {
        let geo: Geometry
        func path(in rect: CGRect) -> Path {
            var p = geo.linePath
            p.addLine(to: CGPoint(x: rect.width, y: rect.height))
            p.addLine(to: CGPoint(x: 0, y: rect.height))
            p.closeSubpath()
            return p
        }
    }
}
