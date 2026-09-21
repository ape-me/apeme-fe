import SwiftUI

/// Phantom-style account list. Tap to make active; + New account; rename / set default.
struct AccountsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var wallets: [Me.WalletRef] = []
    @State private var balances: [String: Double] = [:]
    @State private var busy = false
    @State private var renaming: Me.WalletRef?
    @State private var newLabel = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Accounts").h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            VStack(spacing: 0) {
                ForEach(rows) { w in
                    let active = w.address == app.walletAddress
                    Button { app.auth.switchAccount(w.address); Task { await app.loadWallet(fresh: true) }; dismiss() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: active ? "checkmark.circle.fill" : "circle").font(.system(size: 18)).foregroundStyle(active ? Theme.ink : Theme.faint).frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(w.label ?? "Account \((w.hdIndex ?? 0) + 1)").font(.rowTitle)
                                    if w.isDefault == true { Badge(text: "Default", style: .grey) }
                                }
                                Text(Fmt.short(w.address)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text(balances[w.address].map(Fmt.usd) ?? "…").font(.rowPrice).monospacedDigit()
                        }
                        .padding(.vertical, 8).frame(minHeight: 60).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Rename") { renaming = w; newLabel = w.label ?? "" }
                        if w.isDefault != true { Button("Make default") { Task { await patch(w.address, isDefault: true) } } }
                    }
                }
            }
            if let error { Text(error).font(.sub).foregroundStyle(Theme.red) }
            BigButton(label: busy ? "Creating…" : "+ New account", style: .ghost) {
                guard !busy else { return }
                busy = true
                Task {
                    defer { busy = false }
                    do { let a = try await app.auth.createAdditionalWallet(); await load(); app.show("Account \(Fmt.short(a)) created") }
                    catch { self.error = "\(error)" }
                }
            }
            Text("Hold a row to rename or make it the default.").font(.sub).foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .task { await load() }
        .alert("Rename account", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Label", text: $newLabel)
            Button("Save") { if let w = renaming { Task { await patch(w.address, label: newLabel) } }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    /// BE list, or Privy's local wallets when the BE hasn't synced them yet.
    private var rows: [Me.WalletRef] {
        if !wallets.isEmpty { return wallets }
        return app.auth.wallets.enumerated().map { i, w in Me.WalletRef(address: w.address, chain: "solana", label: i == 0 ? "Main" : "Account \(i + 1)", isDefault: i == 0, hdIndex: i, createdAt: nil) }
    }

    private func load() async {
        if let r = try? await API.shared.myWallets() { wallets = r.wallets }
        for w in rows where balances[w.address] == nil {
            if let b = try? await API.shared.wallet(w.address, activity: 0) { balances[w.address] = b.totalUsd ?? 0 }
        }
    }

    private func patch(_ address: String, label: String? = nil, isDefault: Bool? = nil) async {
        do { wallets = try await API.shared.patchWallet(address, label: label, isDefault: isDefault).wallets }
        catch { self.error = TradeStore.message(error) }
    }
}
