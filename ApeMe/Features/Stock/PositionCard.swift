import SwiftUI

/// What you hold of this one stock: size, what it's worth, and how the position is doing.
/// Reads the wallet that is already loaded — the stock page fetches nothing extra for it.
struct PositionCard: View {
    let holding: Holding
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Your position")
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Fmt.cash(holding.valueUsd))
                            .font(.system(size: 26, weight: .bold)).tracking(-0.8).monospacedDigit()
                        Text("\(Fmt.qty(holding.amount, symbol: "")) \(symbol)")
                            .font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if let pct = holding.pnlPct, let usd = holding.pnlUsd {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(usd >= 0 ? "+" : "−")\(Fmt.cash(abs(usd)))")
                                .font(.system(size: 17, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(Theme.change(pct))
                            Text(Fmt.pct(pct)).font(.sub).monospacedDigit().foregroundStyle(Theme.change(pct))
                        }
                    }
                }
                Divider().overlay(Theme.line)
                HStack {
                    stat("Avg entry", holding.avgEntryUsd.map(Fmt.usd) ?? "—")
                    Spacer()
                    stat("Cost", holding.costUsd.map(Fmt.cash) ?? "—", trailing: true)
                }
                if holding.costUsd == nil {
                    Text("Bought outside Stonks247, so there's no cost to compare against.")
                        .font(.sub).foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(Theme.surface, in: .rect(cornerRadius: 16))
        }
    }

    private func stat(_ label: String, _ value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            Text(label).font(.system(size: 11, weight: .semibold)).tracking(0.4).foregroundStyle(Theme.faint)
            Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
        }
    }
}
