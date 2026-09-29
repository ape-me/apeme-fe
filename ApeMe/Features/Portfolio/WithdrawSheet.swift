import SwiftUI

/// Send USDC, SOL or a holding to any Solana wallet. Stonks247 charges nothing and pays the network
/// fee and the recipient's account rent, so the only money that goes missing is the issuer's own
/// transfer fee on the tokens that take one — which is why that is the line the review spells out.
struct WithdrawSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var store = WithdrawStore()
    @State private var asset: Holding?
    @State private var to = ""
    @State private var amount = ""
    @FocusState private var focus: Field?

    private enum Field { case address, amount }

    private var wallet: Wallet? { app.wallet }
    private var options: [Holding] {
        guard let w = wallet else { return [] }
        return ([w.cash, w.sol].compactMap { $0 } + w.positions).filter { $0.amount > 0 }
    }
    private var picked: Holding? { asset ?? options.first }
    private var isCash: Bool { picked?.kind == "cash" }
    private var decimals: Int { picked?.decimals ?? (picked?.kind == "sol" ? 9 : 6) }
    /// USDC is typed in dollars; everything else in its own units.
    private var unit: String { isCash ? "$" : "" }
    private var held: Double { picked?.amount ?? 0 }
    private var typed: Double { Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0 }
    private var isMax: Bool { typed >= held * 0.9999 && typed > 0 }

    /// The mint the backend expects: two keywords, otherwise the address.
    private var mintParam: String {
        switch picked?.kind {
        case "cash": "usdc"
        case "sol": "native"
        default: picked?.mint ?? ""
        }
    }

    /// Max sends the exact on-chain balance; anything else is scaled down from it and floored, so a
    /// rounded display figure can never ask for more than the wallet holds.
    private var amountRaw: String? {
        guard let h = picked, typed > 0, held > 0 else { return nil }
        guard let raw = h.raw, !raw.isEmpty, raw != "0", let total = Decimal(string: raw) else {
            return String(Int64((typed * pow(10, Double(decimals))).rounded()))
        }
        if isMax { return raw }
        var scaled = total * Decimal(typed) / Decimal(held)
        var floored = Decimal()
        NSDecimalRound(&floored, &scaled, 0, .down)
        return floored > 0 ? "\(floored)" : nil
    }

    private var canReview: Bool {
        !to.trimmingCharacters(in: .whitespaces).isEmpty && amountRaw != nil && typed <= held + 1e-9 && !store.busy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(store.phase == .done ? "Sent" : "Withdraw").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            .padding(.bottom, 18)

            if store.phase == .done { sent } else if let q = store.quote, store.phase != .quoting { review(q) } else { form }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.ground)
        .presentationDetents([.height(store.phase == .done ? 360 : 560)])
        .presentationBackground(Theme.ground)
        .presentationDragIndicator(.visible)
        .task { if asset == nil { asset = options.first } }
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            picker
            field("To", placeholder: "Solana wallet address", text: $to, focus: .address, mono: true) {
                Button("Paste") { if let s = UIPasteboard.general.string { to = s.trimmingCharacters(in: .whitespacesAndNewlines) } }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            field("Amount", placeholder: isCash ? "0.00" : "0", text: $amount, focus: .amount, mono: false, numeric: true) {
                Button("Max") { amount = isCash ? String(format: "%.2f", floor(held * 100) / 100) : Fmt.plain(held) }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            Text(isCash ? "You have \(Fmt.cash(held))" : "You have \(Fmt.qty(held, symbol: picked?.symbol ?? ""))")
                .font(.sub).foregroundStyle(Theme.muted)

            if let e = store.error { ErrorBar(text: e).padding(.horizontal, -20) }
            Spacer(minLength: 8)

            if store.phase == .quoting {
                HStack(spacing: 10) { ProgressView().tint(.white); Text("Checking…").font(.system(size: 17, weight: .semibold)) }
                    .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Theme.surface2, in: .capsule)
            } else {
                BigButton(label: "Review", style: canReview ? .white : .off) {
                    guard canReview, let from = app.walletAddress, let raw = amountRaw else { return }
                    focus = nil
                    Haptic.medium()
                    store.getQuote(from: from, mint: mintParam, amountRaw: raw, to: to.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .disabled(!canReview)
            }
        }
    }

    private var picker: some View {
        Menu {
            ForEach(options) { h in
                Button {
                    asset = h; amount = ""; store.reset()
                } label: {
                    Text(h.kind == "cash" ? "USDC · \(Fmt.cash(h.valueUsd))" : "\(h.symbol) · \(Fmt.qty(h.amount, symbol: ""))")
                }
            }
        } label: {
            HStack(spacing: 12) {
                Logo(url: picked?.imageURL, symbol: picked?.symbol ?? "—", size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(picked?.symbol ?? "—").font(.system(size: 16, weight: .semibold))
                    Text(isCash ? "Cash" : (picked?.name ?? picked?.symbol ?? "")).font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(14).background(Theme.surface, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func field<T: View>(_ label: String, placeholder: String, text: Binding<String>, focus f: Field,
                                mono: Bool, numeric: Bool = false, @ViewBuilder accessory: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).font(.sub).foregroundStyle(Theme.muted)
                Spacer()
                accessory()
            }
            TextField(placeholder, text: text, axis: mono ? .vertical : .horizontal)
                .font(.system(size: mono ? 14 : 20, weight: mono ? .medium : .semibold, design: mono ? .monospaced : .default))
                .foregroundStyle(Theme.ink)
                .keyboardType(numeric ? .decimalPad : .default)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .lineLimit(mono ? 2 : 1)
                .focused($focus, equals: f)
                .padding(14).background(Theme.surface, in: .rect(cornerRadius: 14))
        }
    }

    // MARK: Review

    private func review(_ q: WithdrawQuote) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isCash ? Fmt.cash(q.usd) : Fmt.qty(typed, symbol: q.symbol ?? ""))
                    .font(.system(size: 30, weight: .semibold)).tracking(-0.8).monospacedDigit()
                Text("to \(Fmt.short(q.to))").font(.sub).foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 20)

            KCard {
                KV("Network fee", q.gas?.paidBy == "user" ? "You pay" : "We pay it")
                KV("Stonks247 fee", (q.fee?.usd ?? 0) <= 0 ? "None" : Fmt.cash(q.fee?.usd))
                if let bps = q.issuerFeeBps, bps > 0 {
                    KV("Issuer transfer fee", "\(String(format: "%g", Double(bps) / 100))%")
                }
                KV("They receive", isCash ? Fmt.cash(q.recipientGetsUsd) : Fmt.qty(typed * (1 - q.issuerFeeRate), symbol: q.symbol ?? ""))
            }

            if let bps = q.issuerFeeBps, bps > 0 {
                Text("\(q.symbol ?? "This token") charges \(String(format: "%g", Double(bps) / 100))% on every transfer. That is the issuer's, not ours.")
                    .font(.sub).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            }
            Text("Sending to the wrong address cannot be undone. Check it once more.")
                .font(.sub).foregroundStyle(Theme.faint).padding(.top, 12)

            if let e = store.error { ErrorBar(text: e).padding(.horizontal, -20).padding(.top, 8) }
            Spacer(minLength: 12)

            if store.busy {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(store.phase == .signing ? "Signing…" : "Sending…").font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 52)
                .background(Theme.surface2, in: .capsule)
            } else {
                HStack(spacing: 10) {
                    BigButton(label: "Back", style: .ghost) { store.reset() }
                    BigButton(label: "Send", style: .white) {
                        guard let w = app.auth.activeWallet else { app.show("Sign in first.", error: true); return }
                        Haptic.medium()
                        Task {
                            await store.send(wallet: w)
                            if store.phase == .done { app.settleWallet() }
                        }
                    }
                }
            }
        }
    }

    private var sent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(Theme.green)
                Text(isCash ? "\(Fmt.cash(store.quote?.usd)) sent" : "\(Fmt.qty(typed, symbol: store.quote?.symbol ?? "")) sent")
                    .font(.system(size: 24, weight: .semibold)).tracking(-0.6)
                Text("to \(Fmt.short(store.quote?.to ?? ""))").font(.sub).foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 22)
            Spacer(minLength: 8)
            BigButton(label: "Done", style: .white) { dismiss() }
        }
    }
}
