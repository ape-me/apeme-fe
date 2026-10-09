import SwiftUI

/// 64pt dividerless stock row: symbol and premium, name, price and today's change.
struct StockRow: View {
    let stock: Stock
    @Environment(AppState.self) private var app

    private var subtitle: String {
        if stock.isPreIPO { return "\(stock.name) · Pre-IPO" }
        // The real ticker is what people know a company by, and it is how they searched for it.
        if let u = stock.underlying, u.lowercased() != stock.symbol.lowercased() {
            return "\(stock.name) · \(u)"
        }
        return stock.name
    }

    var body: some View {
        Button { app.openStock(stock.mint) } label: {
            HStack(spacing: 12) {
                Logo(url: stock.logoURL, symbol: stock.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(stock.symbol).font(.rowTitle).tracking(-0.2).lineLimit(1)
                        if stock.isHalted {
                            Text("HALTED")
                                .font(.system(size: 9, weight: .bold)).tracking(0.4)
                                .foregroundStyle(Theme.amber)
                                .padding(.horizontal, 6).frame(height: 17)
                                .background(Theme.amberT, in: .rect(cornerRadius: 5))
                        } else {
                            PremiumBadge(pct: stock.premiumPct)
                        }
                    }
                    Text(subtitle)
                        .font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let sp = stock.spark, sp.count > 1 {
                    RowSpark(points: sp, baseline: stock.prevClose,
                             tint: RowSpark.tint(points: sp, baseline: stock.prevClose, change: stock.change24h))
                        .padding(.trailing, 6)
                }
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.usd(stock.priceUsd)).font(.rowPrice).monospacedDigit()
                    // An earn token's 24h change is near zero by design; printing it as a market
                    // move makes a working product look like a dead one.
                    if stock.isEarn {
                        Text("earning").font(.rowChange).foregroundStyle(Theme.green)
                    } else {
                        Text(Fmt.arrow(stock.change24h)).font(.rowChange).monospacedDigit()
                            .foregroundStyle(Theme.change(stock.change24h))
                    }
                }
                .frame(minWidth: 92, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }
}
