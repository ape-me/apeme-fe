import SwiftUI

/// 64pt dividerless stock row: symbol and premium, name, price and today's change.
struct StockRow: View {
    let stock: Stock
    @Environment(AppState.self) private var app

    var body: some View {
        Button { app.openStock(stock.mint) } label: {
            HStack(spacing: 12) {
                Logo(url: stock.logoURL, symbol: stock.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(stock.symbol).font(.rowTitle).tracking(-0.2).lineLimit(1)
                        PremiumBadge(pct: stock.premiumPct)
                    }
                    Text(stock.isPreIPO ? "\(stock.name) · Pre-IPO" : stock.name)
                        .font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.usd(stock.priceUsd)).font(.rowPrice).monospacedDigit()
                    Text(Fmt.arrow(stock.change24h)).font(.rowChange).monospacedDigit()
                        .foregroundStyle(Theme.change(stock.change24h))
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }
}
