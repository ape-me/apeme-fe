import SwiftUI

/// Opens a headline in whichever browser the user has set as their default — Safari, Chrome,
/// whatever. No sheet in between: they tapped a headline, they want the article.
@MainActor func openArticle(_ item: NewsItem, _ open: OpenURLAction) {
    guard let url = item.link else { return }
    Haptic.light()
    open(url)
}

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
                Text(item.displayTitle)
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
                    .lineLimit(1).layoutPriority(2)
                }
                .buttonStyle(.plain)
                dot
            }
            Text(item.source).lineLimit(1).truncationMode(.tail).layoutPriority(-1)
            if let ts = item.publishedAt {
                dot
                Text("\(Fmt.ago(ts)) ago").lineLimit(1).layoutPriority(2)
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

/// The top story earns a picture at full width. Pre-IPO stories arrive through Google News
/// wrappers that no server-side scrape can open, so they will never carry a photo — those fall
/// back to the stock's mark centred on a tinted panel, which reads as designed. Stretching the
/// logo would read as broken, and dropping the lead entirely would leave the marquee names
/// looking like the poor relation of the tickers that happen to have art.
struct NewsLead: View {
    let item: NewsItem
    var showSymbol = true
    let open: (NewsItem) -> Void
    let openStock: (String) -> Void

    @ViewBuilder private var art: some View {
        if let photo = item.photoURL {
            RemoteImage(url: photo, fallback: "")
        } else {
            ZStack {
                RadialGradient(colors: [Theme.surface2, Theme.surface], center: .init(x: 0.5, y: 0.45), startRadius: 0, endRadius: 220)
                Logo(url: item.logoURL, symbol: item.symbol, size: 76)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // A 16:9 banner has to be bounded by the width it is offered. `aspectRatio(.fill)`
            // does the opposite — it grows past the proposal to keep the ratio, which made the
            // whole page wider than the screen and shunted every row left of centre.
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay { art.scaledToFill() }
                .clipped()
                .clipShape(.rect(cornerRadius: 14))
            HStack(spacing: 5) {
                if showSymbol {
                    Button { openStock(item.mint) } label: {
                        HStack(spacing: 4) {
                            Text(item.symbol).foregroundStyle(Theme.ink)
                            if let c = item.change24h { Text(Fmt.arrow(c, 2)).foregroundStyle(Theme.change(c)) }
                        }
                        .font(.system(size: 12, weight: .bold)).monospacedDigit().lineLimit(1).fixedSize()
                    }
                    .buttonStyle(.plain)
                    Text("·").foregroundStyle(Theme.faint)
                }
                Text(item.source).lineLimit(1).layoutPriority(-1)
                if let ts = item.publishedAt { Text("·").foregroundStyle(Theme.faint); Text("\(Fmt.ago(ts)) ago").lineLimit(1) }
                if let i = item.impactBadge { NewsBadge.impact(i).padding(.leading, 2) }
                if let d = item.direction { NewsBadge.direction(d) }
                Spacer(minLength: 0)
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
            Text(item.displayTitle)
                .font(.system(size: 19, weight: .bold)).tracking(-0.4).lineSpacing(3)
                .foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .contentShape(.rect)
        .onTapGesture { open(item) }
    }
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
