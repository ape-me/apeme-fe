import SwiftUI

struct PortfolioView: View {
    @Environment(AppState.self) private var app
    @State private var error: String?
    @State private var showPct = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Portfolio").h1Text()
                Spacer()
                Pill(label: "Add money", icon: "plus") { app.sheet = .deposit }
            }
            .padding(.horizontal, 20).padding(.top, 16)
            ScrollView {
                Group {
                    if !app.hasWallet { empty }
                    else if let w = app.wallet { wallet(w) }
                    else if let error { ErrorBar(text: error) }
                    else { Skeleton(height: 44).padding(.top, 12) }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .task(id: app.walletAddress) {
            guard app.hasWallet else { return }
            await app.loadWallet()
            if app.wallet == nil { error = "Couldn't load the wallet." }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(Text("$0"))\(Text(".00").fontWeight(.medium))").heroText().foregroundStyle(Theme.faint).padding(.top, 10)
            Text("No holdings yet").font(.sub).foregroundStyle(Theme.muted).padding(.top, 4)
            Text("Your chart starts with your first buy")
                .font(.sub).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity).frame(height: 120)
                .background(DotGrid())
                .background(Theme.surface)
                .clipShape(.rect(cornerRadius: 16))
                .padding(.top, 20)
            VStack(alignment: .leading, spacing: 14) {
                Text(app.isApe ? "Get your first meme with Apple Pay" : "Buy your first stock with Apple Pay").h3Text()
                Text("$0 fee on your first purchase").font(.sub).foregroundStyle(Theme.muted)
                BigButton(label: app.isApe ? "Ape the king" : "Start with OPENAI", style: .white, small: true) { app.sheet = .deposit }
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(Theme.surface, in: .rect(cornerRadius: 20)).padding(.top, 16)
        }
    }

    private func wallet(_ w: Wallet) -> some View {
        let groups: [(String, String)] = app.isApe ? [("meme", "Memes"), ("sol", "Cash")] : [("stock", "Stocks"), ("sol", "Cash")]
        let activity = app.isApe ? w.activity : w.activity.filter { $0.stockSymbol == nil || app.stocksByMint[$0.mint] != nil }
        return VStack(alignment: .leading, spacing: 0) {
            CentsText(value: w.totalUsd).padding(.top, 10)
            pnlLine(w).padding(.top, 4)

            ForEach(groups, id: \.0) { kind, title in
                let hs = w.holdings.filter { $0.kind == kind }
                if !hs.isEmpty {
                    Text(title).h2Text().padding(.top, 22)
                    VStack(spacing: 0) { ForEach(hs) { HoldingRow(holding: $0) } }.padding(.top, 4)
                }
            }
            if w.holdings.contains(where: { $0.costUsd == nil }) {
                Text("— means bought outside ApeMe, so there's no cost basis.").font(.sub).foregroundStyle(Theme.muted).padding(.top, 8)
            }
            Text("Activity").h2Text().padding(.top, 22)
            VStack(spacing: 0) {
                if activity.isEmpty { EmptyState(title: "No activity yet") }
                ForEach(activity.prefix(20)) { ActivityRow(activity: $0) }
            }
            .padding(.top, 4)
        }
    }

    /// One P&L figure: `↑ $10.90` or `↑ 3.1%`. Tap flips between them.
    private func pnlLine(_ w: Wallet) -> some View {
        let pnl = w.pnlUsd
        let pct: Double? = {
            guard let pnl, let cost = w.costUsd, cost > 0 else { return nil }
            return pnl / cost * 100
        }()
        let value: String = {
            guard let pnl else { return "—" }
            if showPct, let pct { return Fmt.arrow(pct, 1) }
            return (pnl >= 0 ? "↑ " : "↓ ") + Fmt.usd(abs(pnl))
        }()
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { showPct.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(value).foregroundStyle(Theme.change(pnl))
                Text("all time").foregroundStyle(Theme.muted)
            }
            .font(.sub).monospacedDigit()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(pnl == nil)
    }
}

struct HoldingRow: View {
    let holding: Holding
    @Environment(AppState.self) private var app

    var body: some View {
        Button {
            if holding.kind == "meme", app.isApe { app.push(.token(holding.mint)) }
            else if holding.kind == "stock" { app.openStock(holding.mint) }
        } label: {
            HStack(spacing: 12) {
                if holding.kind == "meme" { Avatar(url: holding.imageURL, symbol: holding.symbol) }
                else { Logo(url: holding.imageURL, symbol: holding.symbol) }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(holding.symbol).font(.rowTitle)
                        if let q = holding.quoteSymbol { Text("on \(q)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.faint) }
                    }
                    Text("\(holding.amount >= 1000 ? Fmt.big(holding.amount, "") : String(format: "%.4f", holding.amount)) · \(Fmt.usd(holding.priceUsd))")
                        .font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.usd(holding.valueUsd)).font(.rowPrice).monospacedDigit()
                    Text(holding.pnlPct.map { Fmt.arrow($0, 1) } ?? "—").font(.rowChange).monospacedDigit()
                        .foregroundStyle(holding.pnlPct == nil ? Theme.faint : Theme.change(holding.pnlPct))
                }
            }
            .padding(.vertical, 8).frame(minHeight: 60).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct ActivityRow: View {
    let activity: Activity
    @Environment(AppState.self) private var app

    var body: some View {
        Button { if app.isApe { app.push(.token(activity.mint)) } } label: {
            HStack(spacing: 12) {
                Avatar(url: activity.imageURL, symbol: activity.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Badge(text: activity.side == .buy ? "Buy" : "Sell", style: activity.side == .buy ? .green : .red)
                        Text(activity.symbol).font(.rowTitle)
                    }
                    Text("on \(activity.stockSymbol ?? "—") · \(Fmt.ago(activity.ts)) ago").font(.sub).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(Fmt.usd(activity.usd)).font(.rowPrice).monospacedDigit()
            }
            .padding(.vertical, 8).frame(minHeight: 60).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct DotGrid: View {
    var body: some View {
        Canvas { ctx, size in
            var y = 5.0
            while y < size.height {
                var x = 5.0
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(Theme.line))
                    x += 10
                }
                y += 10
            }
        }
    }
}
