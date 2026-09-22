import SwiftUI

/// MATERIAL / BULLISH. Only the scores the BE stands behind — confidence never reaches the screen.
struct NewsBadge: View {
    let text: String
    let tint: Color
    let fill: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold)).tracking(0.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 6).frame(height: 17)
            .background(fill, in: .rect(cornerRadius: 5))
    }

    static func impact(_ v: String) -> NewsBadge {
        v == "material" ? NewsBadge(text: v, tint: Theme.amber, fill: Theme.amberT)
                        : NewsBadge(text: v, tint: Theme.red, fill: Theme.redT)
    }

    static func direction(_ v: String) -> NewsBadge {
        switch v {
        case "bullish": NewsBadge(text: v, tint: Theme.green, fill: Theme.greenT)
        case "bearish": NewsBadge(text: v, tint: Theme.red, fill: Theme.redT)
        default: NewsBadge(text: v, tint: Theme.muted, fill: Theme.surface2)
        }
    }
}

/// `[logo] NVDAX ▲1.14% · Yahoo Finance · 2h ago  [MATERIAL][BULLISH]` over a two-line headline.
/// The symbol chip goes to the stock; everything else opens the article.
struct NewsRow: View {
    let item: NewsItem
    /// Home shows which stock it is. On a stock's own tab that would be its logo five times, so
    /// there the thumbnail only earns its place when the article brings a real photo.
    var showSymbol = true
    var showThumb = true
    let open: (NewsItem) -> Void
    let openStock: (String) -> Void

    private var thumb: URL? { showThumb ? (item.photoURL ?? item.logoURL) : item.photoURL }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let thumb {
                Button { openStock(item.mint) } label: {
                    RemoteImage(url: thumb, fallback: String(item.symbol.prefix(1)))
                        .frame(width: 40, height: 40)
                        .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 5) {
                meta
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                    .foregroundStyle(Theme.ink).lineSpacing(2).lineLimit(2)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                badges
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { open(item) }
        }
        .padding(.vertical, 14)
    }

    /// One line that never wraps: the symbol and the time hold their width, the source gives way.
    private var meta: some View {
        HStack(spacing: 5) {
            if showSymbol {
                Button { openStock(item.mint) } label: {
                    HStack(spacing: 4) {
                        Text(item.symbol).foregroundStyle(Theme.ink)
                        if let c = item.change24h { Text(Fmt.arrow(c, 2)).foregroundStyle(Theme.change(c)) }
                    }
                    .font(.system(size: 12, weight: .bold)).monospacedDigit()
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
                dot
            }
            Text(item.source).lineLimit(1).truncationMode(.tail)
            if let ts = item.publishedAt {
                dot
                Text("\(Fmt.ago(ts)) ago").fixedSize(horizontal: true, vertical: false)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
    }

    /// Badges sit under the headline, where there is always room to spell them out.
    @ViewBuilder private var badges: some View {
        if item.impactBadge != nil || item.direction != nil {
            HStack(spacing: 6) {
                if let i = item.impactBadge { NewsBadge.impact(i) }
                if let d = item.direction { NewsBadge.direction(d) }
            }
            .padding(.top, 1)
        }
    }

    private var dot: some View { Text("·").foregroundStyle(Theme.faint) }
}

/// A list of headlines with hairlines between, and nothing above the first or below the last.
struct NewsList: View {
    let items: [NewsItem]
    var showSymbol = true
    var showThumb = true
    let open: (NewsItem) -> Void
    let openStock: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                if i > 0 { Divider().overlay(Theme.line) }
                NewsRow(item: item, showSymbol: showSymbol, showThumb: showThumb, open: open, openStock: openStock)
            }
        }
    }
}
