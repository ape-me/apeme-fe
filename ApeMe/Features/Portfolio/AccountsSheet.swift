import SwiftUI

/// One card per account: a disc with its initial, the name and address, what it holds on the
/// right, a copy button and a menu that shows what can be done to it. Tap the card to switch.
struct AccountsSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.skin) private var skin
    @State private var wallets: [Me.WalletRef] = []
    @State private var balances: [String: Double] = [:]
    @State private var positions: [String: Int] = [:]
    /// Reads that failed, so the card says "—" rather than loading forever.
    @State private var failed: Set<String> = []
    @State private var busy = false
    @State private var renaming: Me.WalletRef?
    @State private var newLabel = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Accounts").h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(rows) { w in card(w) }
                }
            }
            .scrollIndicators(.hidden)
            if let error { ErrorBar(text: error).padding(.horizontal, -20) }
            BigButton(label: busy ? "Creating…" : "+ New account", style: .primary) {
                guard !busy else { return }
                busy = true; error = nil
                Task {
                    defer { busy = false }
                    do { let a = try await app.auth.createAdditionalWallet(); await load(); app.show("Account \(Fmt.short(a)) created") }
                    catch { self.error = Failure.action(error) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.ground)
        .presentationDragIndicator(.visible)
        .task { await load() }
        .alert("Rename account", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newLabel)
            Button("Save") {
                let name = newLabel.trimmingCharacters(in: .whitespaces)
                if let w = renaming, !name.isEmpty, name != w.label { Task { await patch(w.address, label: String(name.prefix(24))) } }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: { Text("Up to 24 characters.") }
    }

    private func name(_ w: Me.WalletRef) -> String { w.label ?? "Account \((w.hdIndex ?? 0) + 1)" }

    private func card(_ w: Me.WalletRef) -> some View {
        let active = w.address == app.walletAddress
        return HStack(spacing: 12) {
            Button {
                guard !active else { dismiss(); return }
                Haptic.selection()
                app.auth.switchAccount(w.address)
                Task { await app.loadWallet(fresh: true) }
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Text(String(name(w).prefix(1)).uppercased())
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(skin.accent)
                            .frame(width: 44, height: 44)
                            .background(skin.accentTint, in: .circle)
                        if active {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 18, height: 18).background(skin.accent, in: .circle)
                                .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                                .offset(x: 16, y: 16)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(name(w)).font(.rowTitle).lineLimit(1)
                            if w.isDefault == true { Badge(text: "Default", style: .grey) }
                        }
                        Text(Fmt.short(w.address)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        if let b = balances[w.address] {
                            Text(Fmt.usd(b)).font(.rowPrice).monospacedDigit()
                            Text(positionsLabel(w)).font(.sub).foregroundStyle(Theme.muted)
                        } else if failed.contains(w.address) {
                            Text("—").font(.rowPrice).foregroundStyle(Theme.faint)
                            Text("Couldn't read").font(.sub).foregroundStyle(Theme.faint)
                        } else {
                            Skeleton(height: 15).frame(width: 64)
                            Skeleton(height: 11).frame(width: 48)
                        }
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            IconButton(symbol: "square.on.square", label: "Copy address") { app.copy(w.address) }
            Menu {
                Button { renaming = w; newLabel = w.label ?? "" } label: { Label("Rename", systemImage: "pencil") }
                if w.isDefault != true {
                    Button { Task { await patch(w.address, isDefault: true) } } label: { Label("Make default", systemImage: "star") }
                }
                Button { app.copy(w.address) } label: { Label("Copy address", systemImage: "square.on.square") }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40).background(Theme.surface2, in: .circle)
            }
            .accessibilityLabel("More")
        }
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? skin.accent : Theme.line, lineWidth: active ? 1.5 : 1))
    }

    private func positionsLabel(_ w: Me.WalletRef) -> String {
        switch positions[w.address] ?? 0 {
        case 0: "No positions"
        case 1: "1 position"
        case let n: "\(n) positions"
        }
    }

    /// BE list, or Privy's local wallets when the BE hasn't synced them yet.
    private var rows: [Me.WalletRef] {
        if !wallets.isEmpty { return wallets }
        return app.auth.wallets.enumerated().map { i, w in Me.WalletRef(address: w.address, chain: "solana", label: i == 0 ? "Main" : "Account \(i + 1)", isDefault: i == 0, hdIndex: i, createdAt: nil) }
    }

    /// Every balance at once; a slow or failed one does not hold up the others.
    private func load() async {
        if let r = try? await API.shared.myWallets() { wallets = r.wallets }
        await withTaskGroup(of: (String, Wallet?).self) { group in
            for w in rows where balances[w.address] == nil {
                group.addTask { (w.address, try? await API.shared.wallet(w.address, activity: 0)) }
            }
            for await (address, wallet) in group {
                if let wallet {
                    balances[address] = wallet.totalUsd ?? 0
                    positions[address] = wallet.positions.count
                    failed.remove(address)
                } else {
                    failed.insert(address)
                }
            }
        }
    }

    private func patch(_ address: String, label: String? = nil, isDefault: Bool? = nil) async {
        error = nil
        do { wallets = try await API.shared.patchWallet(address, label: label, isDefault: isDefault).wallets }
        catch { self.error = Failure.action(error) }
    }
}
