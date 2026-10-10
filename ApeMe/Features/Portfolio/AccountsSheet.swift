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
    @State private var height: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Accounts").h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            VStack(spacing: 10) {
                ForEach(rows) { w in card(w) }
            }
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
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxWidth: .infinity, alignment: .top)
        // As tall as its accounts and no more; a long list scrolls inside the full sheet.
        .presentationDetents(height > 0 ? [.height(min(height + 10, UIScreen.main.bounds.height * 0.9))] : [.large])
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

    /// Name and address get the width; the two actions are small and on the right; what the
    /// account holds sits on its own line under a hairline, so nothing has to truncate.
    private func card(_ w: Me.WalletRef) -> some View {
        let active = w.address == app.walletAddress
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
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
                                if w.isDefault == true { Badge(text: "Default", style: .grey).fixedSize() }
                            }
                            Text(Fmt.short(w.address)).font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 8)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Button { app.copy(w.address) } label: {
                    Image(systemName: "square.on.square").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 34).background(Theme.surface2, in: .circle)
                }
                .buttonStyle(.plain).accessibilityLabel("Copy address")
                Menu {
                    Button { renaming = w; newLabel = w.label ?? "" } label: { Label("Rename", systemImage: "pencil") }
                    if w.isDefault != true {
                        Button { Task { await patch(w.address, isDefault: true) } } label: { Label("Make default", systemImage: "star") }
                    }
                    Button { app.copy(w.address) } label: { Label("Copy address", systemImage: "square.on.square") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 34).background(Theme.surface2, in: .circle)
                }
                .accessibilityLabel("More")
            }
            .padding(14)
            Rectangle().fill(Theme.line).frame(height: 1).padding(.horizontal, 14)
            HStack {
                if let b = balances[w.address] {
                    Text(Fmt.usd(b)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                    Spacer()
                    Text(positionsLabel(w)).font(.sub).foregroundStyle(Theme.muted)
                } else if failed.contains(w.address) {
                    Text("Couldn't read this account").font(.sub).foregroundStyle(Theme.faint)
                    Spacer()
                    Button("Retry") { Task { await load(force: w.address) } }.font(.sub.weight(.semibold)).foregroundStyle(Theme.accent)
                } else {
                    Skeleton(height: 15).frame(width: 72)
                    Spacer()
                    Skeleton(height: 11).frame(width: 64)
                }
            }
            .padding(.horizontal, 14).frame(height: 42)
        }
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
    private func load(force: String? = nil) async {
        if force == nil, let r = try? await API.shared.myWallets() { wallets = r.wallets }
        if let force { failed.remove(force) }
        await withTaskGroup(of: (String, Wallet?).self) { group in
            for w in rows where balances[w.address] == nil && (force == nil || w.address == force) {
                // The backend wants at least one activity row; zero is refused.
                group.addTask { (w.address, try? await API.shared.wallet(w.address, activity: 1)) }
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
