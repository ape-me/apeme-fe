import SwiftUI

/// The basket's cover: the top of the screen, edge to edge, in the app's blue. The stocks in
/// it, its name and tagline, and whatever number the screen is about. The same block opens the
/// basket page, both sheets and the position page, so a basket looks like itself everywhere.
///
/// `bar` is the row that sits in the cover's top band: a sheet's title and close button. Pages
/// leave it empty and pin their back button over the band instead, so it is still there once
/// the cover has scrolled away.
/// One cell of the strip under a cover: the number, and what it is.
struct CoverStat: Hashable {
    let label: String
    let value: String
    var color: Color = Theme.ink
}

struct BasketCover<Bar: View, Trailing: View>: View {
    let name: String
    var tagline: String? = nil
    let logos: [URL]
    /// The value of $100 over the period, drawn as a sparkline. Empty draws nothing.
    var chart: [Double] = []
    var chartTint: Color = Theme.accent
    /// Up to four, edge to edge.
    var stats: [CoverStat] = []
    @ViewBuilder let bar: Bar
    @ViewBuilder let trailing: Trailing

    init(name: String, tagline: String? = nil, logos: [URL], chart: [Double] = [], chartTint: Color = Theme.accent, stats: [CoverStat] = [],
         @ViewBuilder bar: () -> Bar = { EmptyView() }, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.name = name; self.tagline = tagline; self.logos = logos
        self.chart = chart; self.chartTint = chartTint; self.stats = stats
        self.bar = bar(); self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // An EmptyView takes no space whatever frame it is given, so the band is a real
            // 56pt of colour and the bar sits in it.
            ZStack(alignment: .leading) {
                Color.clear.frame(height: 56)
                bar.padding(.horizontal, 12)
            }
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    LogoStack(urls: logos, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.system(size: 22, weight: .semibold)).tracking(-0.5).foregroundStyle(Theme.ink)
                        if let tagline {
                            Text(tagline).font(.sub).foregroundStyle(Theme.muted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Spacer(minLength: 12)
                trailing
            }
            .padding(.horizontal, 20).padding(.top, 4)
            if chart.count > 1 {
                Sparkline(values: chart, tint: chartTint)
                    .frame(height: 60).padding(.horizontal, 20).padding(.top, 16)
            }
            if !stats.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(stats.prefix(4).enumerated()), id: \.offset) { i, st in
                        if i > 0 { Rectangle().fill(Theme.line).frame(width: 1, height: 30).padding(.horizontal, 10) }
                        // A cell is about 70pt. Callers keep values to six characters or so; the
                        // scale factor is only there so a long one loses a little size, not its end.
                        VStack(alignment: .leading, spacing: 3) {
                            Text(st.value).font(.system(size: 15, weight: .semibold)).monospacedDigit().foregroundStyle(st.color)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(st.label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
                                .lineLimit(1).minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity).clipped()
                .padding(.horizontal, 20).padding(.top, 16)
            }
            Color.clear.frame(height: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasketTint.gradient)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// The cover's blue: the accent, washed to a tint that ink and the green and red numbers sit
/// on comfortably. One colour for every basket; the logos tell them apart.
enum BasketTint {
    static var gradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xD6E4FF), Color(hex: 0xEEF4FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A line and the wash under it. No axes, no labels, no touch: the shape of the year at a glance.
struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { g in
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 1e-9)
            let inset: CGFloat = 2
            let n = values.count
            let pt: (Int) -> CGPoint = { i in
                CGPoint(x: g.size.width * CGFloat(i) / CGFloat(max(n - 1, 1)),
                        y: inset + (g.size.height - 2 * inset) * (1 - CGFloat((values[i] - lo) / span)))
            }
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
                .fill(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                line.stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// The cover before the basket has arrived: the same tint from the top of the screen, and a
/// placeholder in every slot the real one fills, so nothing moves when the numbers land.
struct BasketCoverSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 56)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: -40 * 0.32) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle().fill(Theme.accent.opacity(0.10)).frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Skeleton(height: 27).frame(width: 150)
                    Skeleton(height: 18).frame(width: 230)
                }
            }
            .padding(.horizontal, 20).padding(.top, 4)
            Skeleton(height: 60).padding(.horizontal, 20).padding(.top, 16)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    if i > 0 { Rectangle().fill(Theme.line).frame(width: 1, height: 30).padding(.horizontal, 10) }
                    VStack(alignment: .leading, spacing: 3) {
                        Skeleton(height: 18).frame(width: 52)
                        Skeleton(height: 13).frame(width: 36)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)
            Color.clear.frame(height: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasketTint.gradient)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
