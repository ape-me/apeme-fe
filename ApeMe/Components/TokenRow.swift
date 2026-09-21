import SwiftUI

/// 60pt meme row, market cap on the right, progress bar under curve tokens.
struct TokenRow: View {
    let token: TokenCard
    var stockSymbol: String? = nil
    var isKing = false
    var flash: Flash? = nil
    @Environment(AppState.self) private var app

    var body: some View {
        Button { app.push(.token(token.mint)) } label: {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Avatar(url: token.imageURL, symbol: token.displaySymbol)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(token.displaySymbol).font(.rowTitle).tracking(-0.2).lineLimit(1)
                            if isKing { Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(Theme.amber) }
                            age
                            if let stockSymbol {
                                Text("on \(stockSymbol)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.faint)
                            }
                        }
                        subtitle
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Fmt.big(token.mcapUsd)).font(.rowPrice).monospacedDigit()
                            Text("MC").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.faint)
                        }
                        Text(Fmt.arrow(token.change24h, 1)).font(.rowChange).monospacedDigit()
                            .foregroundStyle(Theme.change(token.change24h))
                    }
                }
                if token.phase != .graduated {
                    ProgressBar(pct: token.progressPct ?? 0)
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background { FlashBackground(flash: flash) }
    }

    @ViewBuilder private var age: some View {
        if token.isFresh {
            HStack(spacing: 4) {
                Circle().fill(Theme.green).frame(width: 6, height: 6)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in Text(Fmt.ago(token.createdAt, now: ctx.date)) }
            }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.green)
        } else {
            Text(Fmt.ago(token.createdAt)).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.faint)
        }
    }

    private var subtitle: some View {
        let vol = Text(Fmt.big(token.vol24hUsd) + " vol · ")
        let tail: Text = token.phase == .graduated
            ? Text("\(Text(Fmt.n(token.buys24h)).foregroundStyle(Theme.green))/\(Text(Fmt.n(token.sells24h)).foregroundStyle(Theme.red))")
            : Text("\(Int((token.progressPct ?? 0).rounded()))% to graduate").foregroundStyle(Theme.amber)
        return Text("\(vol)\(tail)")
            .font(.sub).monospacedDigit().foregroundStyle(Theme.muted).lineLimit(1)
    }
}

struct ProgressBar: View {
    let pct: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(Theme.amber).frame(width: g.size.width * min(1, max(0, pct / 100)))
            }
        }
        .frame(height: 3)
    }
}

/// A trade just landed on this row: tint for 400ms.
struct Flash: Equatable {
    let side: Side
    let stamp: Int
}

struct FlashBackground: View {
    let flash: Flash?
    @State private var alpha = 0.0

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill((flash.map { $0.side == .buy ? Theme.greenT : Theme.redT } ?? .clear).opacity(alpha))
            .onChange(of: flash?.stamp) { _, _ in
                alpha = 1
                withAnimation(.easeOut(duration: 0.45).delay(0.1)) { alpha = 0 }
            }
    }
}
