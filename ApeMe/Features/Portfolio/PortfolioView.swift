import SwiftUI

/// Wallet tab: cash first, then positions and activity for the active account.
struct PortfolioView: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @State private var error: String?
    @State private var showAccounts = false
    @State private var poller: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { showAccounts = true } label: {
                    HStack(spacing: 6) {
                        Text(accountLabel).h1Text()
                        Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Pill(label: "Deposit", icon: "plus") { app.sheet = .deposit }
            }
            .padding(.horizontal, 20).padding(.top, 16)
            ScrollView {
                Group {
                    if let w = app.wallet { content(w) }
                    else if let error { ErrorBar(text: error) }
                    else { Skeleton(height: 44).padding(.top, 12) }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable { await app.loadWallet(fresh: true) }
        }
        .background(Theme.ground)
        .task(id: app.walletAddress) {
            await app.loadWallet(fresh: true)
            if app.wallet == nil { error = "Couldn't load the wallet." }
        }
        .onChange(of: app.wallet?.pendingSwaps ?? 0, initial: true) { _, pending in
            poller?.cancel()
            guard pending > 0 else { return }
            poller = Task {
                while !Task.isCancelled, (app.wallet?.pendingSwaps ?? 0) > 0 {
                    try? await Task.sleep(for: .seconds(3))
                    await app.loadWallet(fresh: true)
                }
            }
        }
        .onDisappear { poller?.cancel() }
        .sheet(isPresented: $showAccounts) { AccountsSheet() }
    }

    private var accountLabel: String {
        app.auth.me?.wallets?.first { $0.address == app.walletAddress }?.label ?? "Wallet"
    }

    @ViewBuilder private func content(_ w: Wallet) -> some View {
        if w.isEmpty { empty } else { filled(w) }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 0) {
            CentsText(value: 0).foregroundStyle(Theme.faint).padding(.top, 10)
            Text("No cash yet").font(.sub).foregroundStyle(Theme.muted).padding(.top, 4)
            VStack(alignment: .leading, spacing: 14) {
                Text("Deposit USDC to start").h3Text()
                Text("Send USDC on Solana from any wallet or exchange. Trades are gas-free.").font(.sub).foregroundStyle(Theme.muted)
                BigButton(label: "Deposit", style: .white, small: true) { app.sheet = .deposit }.fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(Theme.surface, in: .rect(cornerRadius: 20)).padding(.top, 20)
        }
    }

    private func filled(_ w: Wallet) -> some View {
        let hideDust = app.auth.settings.hideDust ?? false
        let positions = w.positions.filter { !hideDust || ($0.valueUsd ?? 0) >= 0.01 }
        return VStack(alignment: .leading, spacing: 0) {
            CentsText(value: w.cashUsd ?? 0).padding(.top, 10)
            HStack(spacing: 4) {
                Text("Portfolio \(Fmt.usd(w.totalUsd))").foregroundStyle(Theme.muted)
                if let p = w.pnlUsd, p != 0 {
                    Text("·").foregroundStyle(Theme.faint)
                    Text((p >= 0 ? "↑ " : "↓ ") + Fmt.usd(abs(p))).foregroundStyle(Theme.change(p))
                }
                if (w.pendingSwaps ?? 0) > 0 {
                    Text("·").foregroundStyle(Theme.faint)
                    Text("\(w.pendingSwaps ?? 0) pending").foregroundStyle(Theme.muted)
                }
            }
            .font(.sub).monospacedDigit().padding(.top, 4)
            HStack(spacing: 8) {
                Pill(label: "Deposit", icon: "plus") { app.sheet = .deposit }
                Pill(label: "Withdraw · soon", size: .regular) {}.opacity(0.5)
            }
            .padding(.top, 16)

            if !positions.isEmpty {
                Text("Positions").h2Text().padding(.top, 26)
                VStack(spacing: 0) { ForEach(positions) { PositionRow(holding: $0) } }.padding(.top, 4)
            }
            if let sol = w.sol, (sol.valueUsd ?? 0) > 0 {
                HStack { Text("SOL").font(.sub).foregroundStyle(Theme.muted); Spacer(); Text(Fmt.usd(sol.valueUsd)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted) }.padding(.top, 8)
            }
            Text("Activity").h2Text().padding(.top, 26)
            VStack(spacing: 0) {
                if w.activity.isEmpty { EmptyState(title: "Nothing yet.") }
                ForEach(w.activity.prefix(30)) { ActivityRow(activity: $0) }
            }
            .padding(.top, 4)
        }
    }
}

struct PositionRow: View {
    let holding: Holding
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if holding.kind == "meme" { if app.isApe { app.push(.token(holding.mint)) } }
                else { app.openStock(holding.mint) }
            } label: {
                HStack(spacing: 12) {
                    if holding.kind == "meme" { Avatar(url: holding.imageURL, symbol: holding.symbol) }
                    else { Logo(url: holding.imageURL, symbol: holding.symbol) }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(holding.symbol).font(.rowTitle)
                            if let q = holding.quoteSymbol { Text("on \(q)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.faint) }
                        }
                        Text("\(Fmt.qty(holding.amount, symbol: "")) · \(Fmt.usd(holding.priceUsd))").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(Fmt.usd(holding.valueUsd)).font(.rowPrice).monospacedDigit()
                        Text(holding.pnlPct.map { Fmt.arrow($0, 1) } ?? Fmt.arrow(holding.change24h, 1)).font(.rowChange).monospacedDigit()
                            .foregroundStyle(Theme.change(holding.pnlPct ?? holding.change24h))
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Pill(label: "Sell", size: .small) { app.sheet = .sell(holding) }
        }
        .padding(.vertical, 8).frame(minHeight: 60)
    }
}

struct ActivityRow: View {
    let activity: Activity
    @Environment(\.openURL) private var openURL

    private var title: String {
        let a = activity
        switch a.kind {
        case "buy": return "Bought \(Fmt.qty(a.amount ?? 0, symbol: a.symbol)) · \(Fmt.usd(a.usd))"
        case "sell": return "Sold \(Fmt.qty(a.amount ?? 0, symbol: a.symbol)) · \(Fmt.usd(a.usd))"
        case "deposit": return "Received \(Fmt.usd(a.usd)) \(a.symbol)"
        case "withdraw": return "Sent \(Fmt.usd(a.usd)) \(a.symbol)"
        default: return "\(a.kind.capitalized) \(a.symbol)"
        }
    }
    private var sub: String {
        var parts: [String] = [Fmt.ago(activity.ts) + " ago"]
        if let s = activity.stockSymbol, activity.kind == "buy" || activity.kind == "sell" { parts.insert("on \(s)", at: 0) }
        if let f = activity.feeUsd { parts.append("fee \(Fmt.usd(f))") }
        if let from = activity.from, activity.kind == "deposit" { parts.append("from \(Fmt.short(from))") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button { if let u = activity.solscanURL { openURL(u) } } label: {
            HStack(spacing: 12) {
                Avatar(url: activity.imageURL, symbol: activity.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(title).font(.rowTitle).lineLimit(1)
                        if activity.status == "pending" { Badge(text: "Pending", style: .grey) }
                        if activity.status == "failed" { Badge(text: "Failed", style: .red) }
                    }
                    Text(activity.status == "failed" ? (activity.error ?? "Failed") : sub).font(.sub).foregroundStyle(activity.status == "failed" ? Theme.red : Theme.muted).lineLimit(1)
                }
                Spacer()
                if activity.status == "pending" { ProgressView().tint(Theme.muted) }
                else if activity.sig != nil { Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint) }
            }
            .padding(.vertical, 8).frame(minHeight: 60).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
