import SwiftUI

/// 64pt dividerless stock row. Invest: price + change. Ape: meme volume + launches.
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
                        if !app.isApe { PremiumBadge(pct: stock.premiumPct) }
                    }
                    subtitle
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    if app.isApe {
                        Text(Fmt.big(stock.memeVol24hUsd)).font(.rowPrice).monospacedDigit()
                        Text("\(stock.launched24h ?? 0) launched").font(.rowChange).foregroundStyle(Theme.muted)
                    } else {
                        Text(Fmt.usd(stock.priceUsd)).font(.rowPrice).monospacedDigit()
                        Text(Fmt.arrow(stock.change24h)).font(.rowChange).monospacedDigit()
                            .foregroundStyle(Theme.change(stock.change24h))
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var subtitle: some View {
        if app.isApe {
            HStack(spacing: 6) {
                Text("\(stock.memes) memes · \(Fmt.big(stock.memeVol24hUsd)) today")
                if let k = stock.king {
                    Text("·").foregroundStyle(Theme.faint)
                    Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(Theme.amber)
                    Avatar(url: k.imageURL, symbol: k.symbol, size: 16)
                    Text(k.symbol)
                }
            }
            .font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
        } else {
            Text(stock.isPreIPO ? "\(stock.name) · Pre-IPO" : stock.name)
                .font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
        }
    }
}
