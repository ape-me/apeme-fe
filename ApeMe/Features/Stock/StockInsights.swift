import SwiftUI

/// Overview, cut to what someone deciding whether to tap Buy actually reads:
/// is it cheap, where is it in its year, is it busy here, does it pay anything.

/// `Nasdaq $87.99 · 21s ago · here −0.4%` while the market trades; once it shuts the same number
/// is yesterday's close, so say that instead of dressing it up as live.
/// The comparison a first-timer actually needs, as a card rather than a grey run-on line:
/// is the US market open right now, what does the real share cost there, and am I better or
/// worse off buying it here. The card is tinted by the answer so the verdict reads before the
/// words do. Pre-IPO names have no Nasdaq listing, so there is no card at all — never a dash.
struct NasdaqCard: View {
    let insights: Insights
    @State private var pulse = false

    private var premium: Double? { insights.premiumVsLastPct }
    private var isOpen: Bool { insights.market?.isLive ?? false }

    /// Neutral inside ±0.5%, amber past +1% (paying up), green past −1% (cheaper here).
    private var tint: Color {
        guard let p = premium else { return Theme.muted }
        if p > 1 { return Theme.amber }
        if p < -1 { return Theme.green }
        return Theme.muted
    }
    private var fill: Color {
        guard let p = premium else { return Theme.surface }
        if p > 1 { return Theme.amberT }
        if p < -1 { return Theme.greenT }
        return Theme.surface
    }

    /// Plain English, and never a minus sign doing the talking.
    private var verdict: String {
        guard let p = premium else { return isOpen ? "Trading alongside Nasdaq" : "Nasdaq is shut — we trade 24/7" }
        let target = isOpen ? "on Nasdaq" : "Nasdaq's last close"
        if abs(p) < 0.5 { return "Same price as \(target) right now" }
        return p > 0 ? "\(String(format: "%.2f", p))% more expensive here than \(target)"
                     : "\(String(format: "%.2f", abs(p)))% cheaper here than \(target)"
    }

    var body: some View {
        if let n = insights.nasdaq, let last = n.last {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(isOpen ? Theme.green : Theme.faint)
                        .frame(width: 7, height: 7)
                        .opacity(isOpen && pulse ? 0.35 : 1)
                    Text(isOpen ? "NASDAQ OPEN" : "NASDAQ CLOSED")
                        .font(.system(size: 11, weight: .bold)).tracking(0.7)
                        .foregroundStyle(isOpen ? Theme.green : Theme.muted)
                    Spacer(minLength: 8)
                    Text(isOpen ? "Real share \(Fmt.usd(last))" : "Last close \(Fmt.usd(last))")
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Theme.muted).lineLimit(1)
                }
                Text(verdict)
                    .font(.system(size: 15, weight: .semibold)).tracking(-0.2)
                    .foregroundStyle(tint)
                    .fixedSize(horizontal: false, vertical: true)
                if !isOpen {
                    Text("The US market is shut. ApeMe trades 24/7 — you don't have to wait for the bell.")
                        .font(.system(size: 12)).foregroundStyle(Theme.faint).lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(fill, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.18), lineWidth: 1))
            .onAppear { if isOpen { withAnimation(.easeInOut(duration: 1.1).repeatForever()) { pulse = true } } }
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
