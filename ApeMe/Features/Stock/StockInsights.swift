import SwiftUI

/// Overview, cut to what someone deciding whether to tap Buy actually reads:
/// is it cheap, where is it in its year, is it busy here, does it pay anything.

/// Is the US market open, and what does the real share cost there. One line, because that is all
/// of it: amber while Nasdaq is shut, green while it trades. It holds its height from the first
/// paint so the chart underneath never jumps when the data lands.
struct NasdaqCard: View {
    let insights: Insights?
    var loading = false
    /// Scrubbing the chart replaces the header numbers; the card stays put but steps back.
    var dimmed = false
    @State private var pulse = false

    private static let height: CGFloat = 42

    private var isOpen: Bool { insights?.market?.isLive ?? false }
    private var tint: Color { isOpen ? Theme.green : Theme.amber }
    private var last: Double? { insights?.nasdaq?.last }

    var body: some View {
        Group {
            if let last {
                HStack(spacing: 7) {
                    Circle().fill(tint).frame(width: 7, height: 7)
                        .opacity(isOpen && pulse ? 0.35 : 1)
                    Text(isOpen ? "NASDAQ OPEN" : "NASDAQ CLOSED")
                        .font(.system(size: 11, weight: .bold)).tracking(0.7)
                        .foregroundStyle(tint)
                    Spacer(minLength: 8)
                    Text(isOpen ? "Real share \(Fmt.usd(last))" : "Last close \(Fmt.usd(last))")
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Theme.ink).lineLimit(1)
                }
                .padding(.horizontal, 14)
                .frame(height: Self.height)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.10), in: .rect(cornerRadius: 12))
                .onAppear { if isOpen { withAnimation(.easeInOut(duration: 1.1).repeatForever()) { pulse = true } } }
            } else if loading {
                Skeleton(height: Self.height)
            }
        }
        .opacity(dimmed ? 0.35 : 1)
    }
}

struct RangeBar: View {
    let position: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface2).frame(height: 6)
                Circle().fill(Theme.ink)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                    .offset(x: (geo.size.width - 12) * position)
            }
            .frame(height: 12)
        }
        .frame(height: 12)
    }
}

/// Our own market — the one thing no brokerage app can show them. The depth ladder turns
/// "very large orders move the price" into the actual number at each size.
struct TradingHereCard: View {
    let stock: Stock
    var depth: Depth?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Trading here today")
            KCard(padded: true) {
                VStack(alignment: .leading, spacing: 14) {
                    line("Traded", Fmt.big(stock.stockVol24hUsd))
                    line("In the pool", Fmt.big(stock.liquidityUsd))
                    SplitBar(a: stock.buys24h, b: stock.sells24h)
                    if let levels = depth?.levels, !levels.isEmpty {
                        Divider().overlay(Theme.line)
                        ladder(levels)
                    }
                    Text(sentence)
                        .font(.sub).foregroundStyle(depth?.notable != nil ? Theme.amber : Theme.muted)
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// What each order size costs you, side by side, so the shape of the pool reads at a glance.
    private func ladder(_ levels: [Depth.Level]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What it costs to buy").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
            HStack(spacing: 8) {
                ForEach(levels) { level in
                    VStack(spacing: 3) {
                        Text(Fmt.big(level.usd)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                        Text(impactText(level)).font(.system(size: 13, weight: .bold)).foregroundStyle(tint(level))
                    }
                    .monospacedDigit()
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(Theme.surface2, in: .rect(cornerRadius: 10))
                }
            }
        }
    }

    private func impactText(_ l: Depth.Level) -> String {
        guard let p = l.impactPct else { return "—" }
        return p < 0.01 ? "0%" : String(format: "%.2f%%", p)
    }

    private func tint(_ l: Depth.Level) -> Color {
        guard let p = l.impactPct else { return Theme.faint }
        if p > 3 { return Theme.red }
        if p > 1 { return Theme.amber }
        return Theme.ink
    }

    private var sentence: String {
        if let thin = depth?.notable, let p = thin.impactPct {
            return "This pool is thin — a \(Fmt.big(thin.usd)) order moves the price \(String(format: "%.2f", p))%."
        }
        return "Small orders fill at the price above. Very large ones move it."
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 15)).foregroundStyle(Theme.muted)
            Spacer()
            Text(v).font(.system(size: 15, weight: .semibold)).monospacedDigit()
        }
    }
}

/// xStocks reinvest the dividend into the token's rebasing multiplier, so the balance grows on
/// its own. That's a feature, not a yield percentage — say it in those words.
struct DividendCard: View {
    let dividends: Insights.Dividends

    var body: some View {
        if dividends.rebases {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Dividends")
                KCard(padded: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Paid as extra tokens").font(.system(size: 15, weight: .semibold))
                        if dividends.hasPaid, let g = dividends.growthSinceLaunchPct {
                            Text("You don't collect anything — your balance just grows. It's up \(Text(String(format: "%.2f%%", g)).foregroundStyle(Theme.green).fontWeight(.semibold)) since this token launched.")
                                .font(.sub).foregroundStyle(Theme.muted).lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Reinvested into your balance automatically, no action needed. Nothing paid out yet.")
                                .font(.sub).foregroundStyle(Theme.muted).lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

/// A date on the calendar, not a warning — and only once it's close enough to act on.
struct EarningsNote: View {
    let insights: Insights

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; f.timeZone = .gmt; return f
    }()

    var body: some View {
        if let e = insights.earnings, let days = e.inDays, (0...14).contains(days), let day = e.day {
            let who = insights.company?.shortName ?? insights.ticker ?? insights.symbol
            let when = e.when == "after close" ? ", after Nasdaq closes" : (e.when.map { ", \($0)" } ?? "")
            VStack(alignment: .leading, spacing: 3) {
                Text("\(who) reports results in \(days) day\(days == 1 ? "" : "s")")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("\(Self.fmt.string(from: day))\(when). Prices usually move hard — and we're open when other apps aren't.")
                    .font(.sub).foregroundStyle(Theme.muted).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Theme.surface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
        }
    }
}
