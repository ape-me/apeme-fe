import SwiftUI

/// Overview, cut to what someone deciding whether to tap Buy actually reads:
/// is it cheap, where is it in its year, is it busy here, does it pay anything.

/// `Nasdaq $87.99 · 21s ago · here −0.4%` while the market trades; once it shuts the same number
/// is yesterday's close, so say that instead of dressing it up as live.
struct NasdaqLine: View {
    let insights: Insights

    var body: some View {
        if let n = insights.nasdaq, let last = n.last {
            let open = insights.market?.isLive ?? false
            let premium = insights.premiumVsLastPct
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(open ? "Nasdaq" : "Nasdaq close")
                    Text(Fmt.usd(last)).foregroundStyle(Theme.ink).fontWeight(.semibold)
                    if open, let asOf = n.asOf { Text("· \(Fmt.ago(asOf)) ago") }
                    if let premium {
                        Text("· here")
                        // Paying above the real share is the bad direction, so the colour flips.
                        Text(Fmt.pct(premium, 2)).foregroundStyle(Theme.change(-premium)).fontWeight(.semibold)
                    }
                }
                if !open {
                    Text("\(insights.market?.label ?? "Closed") — we trade 24/7.").foregroundStyle(Theme.faint)
                }
            }
            .font(.sub).foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
    }
}

/// The 52-week range said out loud: a bar, the two ends, and a sentence. No vocabulary needed.
struct YearRangeCard: View {
    let stats: Insights.Stats
    let price: Double

    private var span: (low: Double, high: Double)? {
        guard let low = stats.low52w, let high = stats.high52w, high > low else { return nil }
        return (low, high)
    }

    private var position: Double {
        guard let s = span else { return 0 }
        return min(1, max(0, (price - s.low) / (s.high - s.low)))
    }

    private var sentence: String {
        switch position {
        case 0.8...: "Near its 12-month high."
        case ...0.2: "Near its 12-month low."
        case 0.55...: "In the upper half of its year."
        case ...0.45: "In the lower half of its year."
        default: "Right in the middle of its year."
        }
    }

    var body: some View {
        if let s = span {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle("Past 12 months")
                KCard(padded: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        RangeBar(position: position)
                        HStack {
                            Text("\(Fmt.usd(s.low)) low")
                            Spacer()
                            Text("\(Fmt.usd(s.high)) high")
                        }
                        .font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.muted)
                        Text(sentence).font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
                    }
                }
            }
        }
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

/// Our own market — the one thing no brokerage app can show them.
struct TradingHereCard: View {
    let stock: Stock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Trading here today")
            KCard(padded: true) {
                VStack(alignment: .leading, spacing: 14) {
                    line("Traded", Fmt.big(stock.stockVol24hUsd))
                    line("In the pool", Fmt.big(stock.liquidityUsd))
                    SplitBar(a: stock.buys24h, b: stock.sells24h)
                    Text("Small orders fill at the price above. Very large ones move it.")
                        .font(.sub).foregroundStyle(Theme.muted).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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
