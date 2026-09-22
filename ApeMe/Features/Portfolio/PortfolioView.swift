import SwiftUI

/// Wallet tab: portfolio value first, cash in its own card, then Positions | Activity.
struct PortfolioView: View {
    enum Tab: String, CaseIterable, Identifiable { case positions, activity; var id: String { rawValue }; var label: String { rawValue.capitalized } }

    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @State private var error: String?
    @State private var showAccounts = false
    @State private var tab: Tab = .positions
    @State private var poller: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
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
        app.auth.me?.wallets?.first { $0.address == app.walletAddress }?.label ?? "Main"
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { showAccounts = true } label: {
                HStack(spacing: 12) {
                    Text(String((app.auth.me?.handle ?? app.auth.accountLabel ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44).background(Theme.surface2, in: .circle)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app.auth.me?.handle.map { "@" + $0 } ?? app.auth.accountLabel ?? "").font(.sub).foregroundStyle(Theme.muted)
                        HStack(spacing: 4) {
                            Text(accountLabel).h2Text()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Spacer()
            IconButton(symbol: "clock", label: "Activity") { tab = .activity }
        }
        .padding(.horizontal, 20).padding(.top, 12)
    }

    @ViewBuilder private func content(_ w: Wallet) -> some View {
        let hideDust = app.auth.settings.hideDust ?? false
        let positions = w.positions.filter { !hideDust || ($0.valueUsd ?? 0) >= 0.01 }
        let invested = (w.totalUsd ?? 0) - (w.cashUsd ?? 0) - (w.solUsd ?? 0)
        let pct: Double? = { guard let p = w.pnlUsd, let c = w.costUsd, c > 0 else { return nil }; return p / c * 100 }()
        VStack(alignment: .leading, spacing: 0) {
            Text("Portfolio value").font(.sub).foregroundStyle(Theme.muted).padding(.top, 8)
            CentsText(value: max(0, invested)).padding(.top, 2)
            HStack(spacing: 8) {
                if let p = w.pnlUsd, !positions.isEmpty {
                    Text((p >= 0 ? "+" : "−") + Fmt.usd(abs(p))).foregroundStyle(Theme.change(p))
                    if let pct {
                        Text(Fmt.arrow(pct, 2)).foregroundStyle(Theme.change(p))
                            .padding(.horizontal, 7).frame(height: 22).background(p >= 0 ? Theme.greenT : Theme.redT, in: .capsule)
                    }
                    Text("·").foregroundStyle(Theme.faint)
                    Text("Invested \(Fmt.usd(w.costUsd))").foregroundStyle(Theme.muted).fontWeight(.medium)
                } else {
                    Text("Nothing invested yet").foregroundStyle(Theme.muted).fontWeight(.medium)
                }
            }
            .font(.system(size: 13, weight: .semibold)).monospacedDigit().padding(.top, 6)

            HStack(spacing: 12) {
                Image("usdc").resizable().frame(width: 40, height: 40).clipShape(.circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cash · USDC").font(.sub).foregroundStyle(Theme.muted)
                    Text(Fmt.usd(w.cashUsd)).font(.system(size: 22, weight: .semibold)).tracking(-0.6).monospacedDigit()
                }
                Spacer()
                Pill(label: "Deposit") { app.sheet = .deposit }
            }
            .padding(16).background(Theme.surface, in: .rect(cornerRadius: 16)).padding(.top, 18)

            HStack(spacing: 8) {
                Pill(label: "Deposit", filled: true, icon: "plus") { app.sheet = .deposit }
                Pill(label: "Withdraw · soon") { app.show("Withdraw is coming soon") }.opacity(0.5)
            }
            .padding(.top, 16)

            UnderlineTabs(items: Tab.allCases, selected: tab, label: \.label) { tab = $0 }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 22)

            Group {
                switch tab {
                case .positions:
                    if positions.isEmpty { EmptyState(title: "No positions yet.", subtitle: "Buy a stock or ape a meme to see it here.") }
                    else { VStack(spacing: 0) { ForEach(positions) { PositionRow(holding: $0) } } }
                case .activity: ActivityList(activity: w.activity)
                }
            }
            .padding(.top, 6)
        }
    }
}

struct PositionRow: View {
    let holding: Holding
    @Environment(AppState.self) private var app

    var body: some View {
        Button { app.sheet = .position(holding) } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    if holding.kind == "meme" { Avatar(url: holding.imageURL, symbol: holding.symbol) } else { Logo(url: holding.imageURL, symbol: holding.symbol) }
                    Text(holding.kind == "meme" ? "MEME" : "STOCK").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4).padding(.vertical, 2).background(Theme.surface2, in: .rect(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.ground, lineWidth: 2)).offset(x: 6, y: 4)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(holding.symbol).font(.rowTitle)
                        if let q = holding.quoteSymbol { Text("on \(q)").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.faint) }
                    }
                    Text(Fmt.qty(holding.amount, symbol: holding.symbol)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Fmt.usd(holding.valueUsd)).font(.rowPrice).monospacedDigit()
                    if let p = holding.pnlUsd { Text((p >= 0 ? "+" : "−") + Fmt.usd(abs(p))).font(.rowChange).monospacedDigit().foregroundStyle(Theme.change(p)) }
                    else { Text(Fmt.arrow(holding.change24h, 1)).font(.rowChange).monospacedDigit().foregroundStyle(Theme.change(holding.change24h)) }
                }
            }
            .padding(.vertical, 8).frame(minHeight: 60).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Grouped by day: Pending first, then Today / Yesterday / date.
struct ActivityList: View {
    let activity: [Activity]

    private var groups: [(String, [Activity])] {
        var out: [(String, [Activity])] = []
        let pending = activity.filter { $0.status == "pending" }
        if !pending.isEmpty { out.append(("Pending", pending)) }
        for a in activity where a.status != "pending" {
            let l = Self.dayLabel(a.ts)
            if let i = out.firstIndex(where: { $0.0 == l }) { out[i].1.append(a) } else { out.append((l, [a])) }
        }
        return out
    }

    static func dayLabel(_ ts: Int) -> String {
        let d = Date(timeIntervalSince1970: TimeInterval(ts))
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInYesterday(d) { return "Yesterday" }
        let sameYear = Calendar.current.component(.year, from: d) == Calendar.current.component(.year, from: .now)
        return sameYear ? d.formatted(.dateTime.month(.abbreviated).day()) : d.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        if activity.isEmpty {
            EmptyState(title: "Nothing yet.", subtitle: "Your deposits and trades show up here.")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups, id: \.0) { label, items in
                    Text(label).font(.eyebrow).foregroundStyle(Theme.muted).padding(.top, 18)
                    ForEach(items) { ActivityRow(activity: $0) }
                }
            }
        }
    }
}

struct ActivityRow: View {
    let activity: Activity
    @Environment(AppState.self) private var app

    private var title: String {
        switch activity.kind {
        case "buy": "Bought \(activity.symbol)"
        case "sell": "Sold \(activity.symbol)"
        case "deposit": "Received USDC"
        case "withdraw": "Sent USDC"
        default: "\(activity.kind.capitalized) \(activity.symbol)"
        }
    }
    private var sub: String {
        let a = activity
        if a.status == "failed" { return "Failed · \(a.error ?? "unknown")" }
        if a.status == "pending" { return "Confirming on Solana…" }
        if a.kind == "deposit" { return "From \(Fmt.short(a.from))" }
        var parts: [String] = []
        if let s = a.stockSymbol { parts.append("on \(s)") }
        parts.append(Fmt.usd(a.usd))
        if let f = a.feeUsd { parts.append("fee \(Fmt.usd(f))") }
        return parts.joined(separator: " · ")
    }
    private var amount: (String, Color)? {
        let a = activity
        if a.status == "failed" { return nil }
        switch a.kind {
        case "buy": return ("+" + Fmt.qty(a.amount ?? 0, symbol: a.symbol), Theme.green)
        case "sell": return ("−" + Fmt.qty(a.amount ?? 0, symbol: a.symbol), Theme.ink)
        case "deposit": return ("+" + Fmt.usd(a.usd), Theme.green)
        case "withdraw": return ("−" + Fmt.usd(a.usd), Theme.ink)
        default: return nil
        }
    }
    private var badge: (String, Color, Color) {
        switch (activity.status, activity.kind) {
        case ("failed", _): ("xmark", Theme.red, .white)
        case (_, "deposit"): ("arrow.down", Theme.green, Theme.ground)
        case (_, "withdraw"): ("arrow.up", Theme.surface2, Theme.ink)
        case (_, "buy"): ("plus", Theme.green, Theme.ground)
        default: ("minus", Theme.red, .white)
        }
    }

    var body: some View {
        Button { app.sheet = .tx(activity) } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    if activity.symbol == "USDC" { Image("usdc").resizable().frame(width: 40, height: 40).clipShape(.circle) }
                    else { Avatar(url: activity.imageURL, symbol: activity.symbol) }
                    let b = badge
                    Image(systemName: b.0).font(.system(size: 9, weight: .bold)).foregroundStyle(b.2)
                        .frame(width: 18, height: 18).background(b.1, in: .circle)
                        .overlay(Circle().stroke(Theme.ground, lineWidth: 2)).offset(x: 3, y: 3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.rowTitle).lineLimit(1)
                    Text(sub).font(.sub).foregroundStyle(activity.status == "failed" ? Theme.red : Theme.muted).lineLimit(1)
                }
                Spacer()
                if activity.status == "pending" { ProgressView().tint(Theme.muted) }
                else if let (t, c) = amount { Text(t).font(.rowPrice).monospacedDigit().foregroundStyle(c) }
            }
            .padding(.vertical, 8).frame(minHeight: 60).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// One transaction: state, date, fee, network, Solscan.
struct TxSheet: View {
    let activity: Activity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var title: String {
        let a = activity
        switch a.kind {
        case "buy": return "Bought \(Fmt.qty(a.amount ?? 0, symbol: a.symbol))"
        case "sell": return "Sold \(Fmt.qty(a.amount ?? 0, symbol: a.symbol))"
        case "deposit": return "Received \(Fmt.usd(a.usd))"
        case "withdraw": return "Sent \(Fmt.usd(a.usd))"
        default: return a.kind.capitalized
        }
    }

    var body: some View {
        let ok = activity.status == "confirmed", pending = activity.status == "pending"
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(activity.kind == "deposit" ? "Deposit" : activity.kind == "withdraw" ? "Withdrawal" : "Trade").h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            VStack(spacing: 14) {
                Group {
                    if pending { ProgressView().tint(Theme.ink) }
                    else { Image(systemName: ok ? "checkmark" : "xmark").font(.system(size: 26, weight: .bold)).foregroundStyle(ok ? Theme.ground : .white) }
                }
                .frame(width: 56, height: 56).background(ok ? Theme.green : pending ? Theme.surface2 : Theme.red, in: .circle)
                Text(title).h1Text().multilineTextAlignment(.center)
                if activity.kind == "buy" || activity.kind == "sell", let u = activity.usd {
                    Text("for \(Fmt.usd(u))" + (activity.stockSymbol.map { " · on \($0)" } ?? "")).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity).padding(.top, 10)
            KCard {
                KV("Date", Fmt.dateTime(activity.ts))
                KV("Status") { Text(ok ? "Succeeded" : pending ? "Pending" : "Failed").foregroundStyle(ok ? Theme.green : pending ? Theme.muted : Theme.red) }
                if let e = activity.error { KV("Reason", e) }
                if let f = activity.feeUsd { KV("Fee", Fmt.usd(f)) }
                if let from = activity.from { KV("From", Fmt.short(from)) }
                KV("Network", "Solana")
            }
            Spacer(minLength: 0)
            if let u = activity.solscanURL { BigButton(label: "View on Solscan", style: .white) { openURL(u) } }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }
}

/// Tap on a position: value, cost, P&L; Buy more / Sell; open the page.
struct PositionSheet: View {
    let holding: Holding
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    if holding.kind == "meme" { Avatar(url: holding.imageURL, symbol: holding.symbol, size: 28) } else { Logo(url: holding.imageURL, symbol: holding.symbol, size: 28) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(holding.symbol).h3Text()
                        Text("\(Fmt.qty(holding.amount, symbol: holding.symbol)) · \(Fmt.usd(holding.valueUsd))").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            KCard {
                KV("Value", Fmt.usd(holding.valueUsd))
                KV("Cost", holding.costUsd.map(Fmt.usd) ?? "—")
                KV("P&L") {
                    if let p = holding.pnlUsd { Text("\((p >= 0 ? "+" : "−") + Fmt.usd(abs(p))) (\(Fmt.pct(holding.pnlPct, 1)))").foregroundStyle(Theme.change(p)) } else { Text("—") }
                }
                KV("Price", Fmt.usd(holding.priceUsd))
            }
            HStack(spacing: 10) {
                BigButton(label: "Buy more", style: .buy) {
                    dismiss()
                    if let s = app.stocksByMint[holding.mint] { app.trade(.buyStock(s)) } else { app.openStock(holding.mint) }
                }
                BigButton(label: "Sell", style: .sell) { dismiss(); app.sheet = .sell(holding) }
            }
            Button {
                dismiss()
                if holding.kind == "meme" { if app.isApe { app.push(.token(holding.mint)) } else { app.show("Switch to Ape mode to open memes") } }
                else { app.openStock(holding.mint) }
            } label: {
                Text("Open \(holding.kind == "meme" ? "token" : "stock") page ›").font(.sub.weight(.semibold)).foregroundStyle(Theme.ink).frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .presentationDetents([.height(360)])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }
}
