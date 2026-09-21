import SwiftUI

struct PortfolioView: View {
    @Environment(AppState.self) private var app
    @State private var error: String?
    @State private var confirmSignOut = false

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
                    if !app.demoWallet { empty }
                    else if let w = app.wallet { wallet(w) }
                    else if let error { ErrorBar(text: error) }
                    else { Skeleton(height: 44).padding(.top, 12) }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .task(id: app.demoWallet) {
            guard app.demoWallet else { return }
            await app.loadWallet()
            if app.wallet == nil { error = "Couldn't load the wallet." }
        }
        .confirmationDialog("Sign out of the demo wallet?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { app.demoWallet = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Portfolio will show the empty state until you sign back in.")
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
            Button { app.demoWallet = true } label: {
                HStack(spacing: 12) {
                    Text("◎").frame(width: 40, height: 40).background(Theme.surface2, in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Use the demo wallet").font(.rowTitle)
                        Text("A real wallet from the tape, with holdings and activity").font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 8).frame(minHeight: 64).contentShape(.rect)
            }
            .buttonStyle(.plain).padding(.top, 12)
        }
    }

    private func wallet(_ w: Wallet) -> some View {
        let groups: [(String, String)] = app.isApe ? [("meme", "Memes"), ("sol", "Cash")] : [("stock", "Stocks"), ("sol", "Cash")]
        let activity = app.isApe ? w.activity : w.activity.filter { $0.stockSymbol == nil || app.stocksByMint[$0.mint] != nil }
        return VStack(alignment: .leading, spacing: 0) {
            CentsText(value: w.totalUsd).padding(.top, 10)
            HStack(spacing: 4) {
                pnl(w.pnlUsd); Text("unrealised").foregroundStyle(Theme.muted).fontWeight(.medium)
                Text("·").foregroundStyle(Theme.muted)
                pnl(w.realizedUsd); Text("realised").foregroundStyle(Theme.muted).fontWeight(.medium)
            }
            .font(.system(size: 13, weight: .semibold)).monospacedDigit().padding(.top, 4)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())], alignment: .leading, spacing: 18) {
                stat(app.isApe ? "Memes" : "Stocks", Fmt.usd(app.isApe ? w.memesUsd : w.stocksUsd))
                stat("Cash (SOL)", Fmt.usd(w.solUsd))
                stat("Cost basis", w.costUsd.map(Fmt.usd) ?? "—")
                stat("Realised", w.realizedUsd.map(Fmt.usd) ?? "—", color: Theme.change(w.realizedUsd))
            }
            .padding(.vertical, 18).padding(.top, 2)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            .padding(.top, 20)

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
            HStack(spacing: 4) {
                Text("Demo wallet \(Fmt.short(w.address)) ·")
                Button("sign out") { confirmSignOut = true }.font(.sub.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            .font(.sub).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding(.top, 20)
        }
    }

    private func pnl(_ v: Double?) -> Text {
        Text(v.map { ($0 >= 0 ? "↑ " : "↓ ") + Fmt.usd(abs($0)) } ?? "—").foregroundStyle(Theme.change(v))
    }

    private func stat(_ label: String, _ value: String, color: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.eyebrow).foregroundStyle(Theme.muted)
            Text(value).font(.stat).tracking(-0.4).monospacedDigit().foregroundStyle(color)
        }
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
