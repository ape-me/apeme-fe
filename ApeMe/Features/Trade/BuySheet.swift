import SwiftUI

/// Amount → Review → Done. Simulated until the swap endpoint lands.
struct BuySheet: View {
    enum Kind { case stock, token }
    let kind: Kind
    let stock: Stock?
    let token: TokenCard?
    let stockRef: StockRef?

    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var amount = "50"

    private var verb: String { kind == .token ? "Ape" : "Buy" }
    private var symbol: String { token?.displaySymbol ?? stock?.symbol ?? "" }
    private var price: Double? { token?.priceUsd ?? stock?.priceUsd }
    private var available: Double { app.wallet?.solUsd ?? 0 }
    private var value: Double { Double(amount) ?? 0 }
    private var qty: Double { price.map { $0 > 0 ? value / $0 : 0 } ?? 0 }
    private var fee: Double { value * 0.0025 }

    var body: some View {
        VStack(spacing: 16) {
            switch step {
            case 0: amountStep
            case 1: reviewStep
            default: doneStep
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .task { if app.demoWallet, app.wallet == nil { await app.loadWallet() } }
    }

    // MARK: Step 1

    private var amountStep: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    if let token { Avatar(url: token.imageURL, symbol: token.displaySymbol, size: 28) }
                    else if let stock { Logo(url: stock.logoURL, symbol: stock.symbol, size: 28) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(verb) \(symbol)").h3Text()
                        Text(Fmt.usd(price) + (kind == .token ? " · on \(stockRef?.symbol ?? "")" : "")).font(.sub).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            VStack(spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(amount.isEmpty ? "0" : amount).font(.amount).tracking(-2.8).monospacedDigit().foregroundStyle(skin.accent)
                    Rectangle().fill(skin.accent).frame(width: 2, height: 48).alignmentGuide(.lastTextBaseline) { $0[.bottom] - 8 }
                    Text("USD").font(.system(size: 40, weight: .medium)).foregroundStyle(Theme.faint)
                }
                Text(price != nil ? "≈ \(Fmt.qty(qty, symbol: symbol))" : "Quote unavailable").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
            }
            .padding(.top, 14).padding(.bottom, 6)
            HStack(spacing: 8) {
                ForEach(["10", "50", "100", "Max"], id: \.self) { p in
                    let on = p == amount
                    Button {
                        amount = p == "Max" ? String(format: "%.2f", floor(available * 100) / 100) : p
                    } label: {
                        Text(p == "Max" ? p : "$" + p)
                            .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(on ? skin.accent : Theme.ink)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(on ? skin.accentTint : Theme.surface2, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            KV("Pay with", app.demoWallet ? "Demo wallet · \(Fmt.usd(available))" : "Add money first")
            Numpad { key in
                switch key {
                case "⌫": amount = String(amount.dropLast())
                case ".": if !amount.contains(".") { amount = (amount.isEmpty ? "0" : amount) + "." }
                default:
                    let decimals = amount.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
                    if amount.count < 8, !amount.contains(".") || decimals < 2 { amount = amount == "0" ? key : amount + key }
                }
            }
            BigButton(label: !app.demoWallet ? "Add money to continue" : value > 0 ? "Review order" : "Enter an amount",
                      style: app.demoWallet && value <= 0 ? .off : .buy) {
                if !app.demoWallet { dismiss(); app.sheet = .deposit; return }
                if value > 0 { step = 1 }
            }
        }
    }

    // MARK: Step 2

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back") { step = 0 }
                Spacer()
                Text("Review").h3Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            Text("\(verb) $\(amount) of \(symbol)").h1Text().padding(.top, 6)
            VStack(spacing: 0) {
                KV("Funding source", "Demo wallet")
                KV("Order type", "Market")
                KV("Approx. price", Fmt.usd(price))
                KV("Approx. \(kind == .token ? "tokens" : "shares")", Fmt.qty(qty, symbol: ""))
                Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 6)
                KV("Amount", "$" + amount)
                KV("Fees", Fmt.usd(fee))
                KV("Total", Fmt.usd(value + fee))
            }
            Text("Prototype order. No funds move. " + (kind == .token ? "Community tokens are unverified and can lose all value." : "Orders route through Jupiter when the swap endpoint lands."))
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
            BigButton(label: "Confirm", style: .buy) { step = 2 }
        }
    }

    // MARK: Step 3

    private var doneStep: some View {
        VStack(spacing: 16) {
            HStack { Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            VStack(spacing: 16) {
                Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.ground)
                    .frame(width: 56, height: 56).background(Theme.green, in: .circle)
                Text("You \(kind == .token ? "aped" : "bought") $\(amount) of \(symbol)").h1Text().multilineTextAlignment(.center)
                if price != nil {
                    Text("≈ \(Fmt.qty(qty, symbol: symbol)) at \(Fmt.usd(price))").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                }
            }
            .padding(.vertical, 12)
            BigButton(label: "Done", style: .white) { dismiss() }
        }
    }
}

struct Numpad: View {
    let onKey: (String) -> Void
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(keys, id: \.self) { k in
                Button { onKey(k) } label: {
                    Group {
                        if k == "⌫" { Image(systemName: "delete.left").font(.system(size: 20)) }
                        else { Text(k).font(.system(size: 24, weight: .medium)) }
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .contentShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(NumpadPress())
                .accessibilityLabel(k == "⌫" ? "Delete" : k)
            }
        }
    }
}

private struct NumpadPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(configuration.isPressed ? Theme.surface2 : .clear, in: .rect(cornerRadius: 12))
    }
}
