import SwiftUI

struct YouView: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin
    @Environment(\.openURL) private var openURL
    @State private var confirmOnboarding = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var editingHandle = false
    @State private var handle = ""
    @State private var handleError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identity

                    if Feature.referrals {
                    Button { app.push(.referrals) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("Invite & earn").h3Text(); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted) }
                            HStack(spacing: 4) {
                                Text(app.auth.me?.referral?.code ?? "——").font(.system(size: 22, weight: .semibold)).tracking(2).monospacedDigit()
                                Spacer()
                                Text("\(app.auth.me?.referral?.invitesLeft ?? 0) left · earned \(Fmt.usd(app.auth.me?.referral?.earnedUsd ?? 0))").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                            }
                            Text("20% of Stonks247's fee on every trade they make, forever.").font(.sub).foregroundStyle(Theme.muted)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: .rect(cornerRadius: 16)).contentShape(.rect)
                    }
                    .buttonStyle(.plain).padding(.top, 12).padding(.bottom, 8)
                    }

                    KCard {
                        SettingRow(symbol: "slider.horizontal.3", title: "Trading settings", sub: "Slippage, quick amounts, confirmations") { app.push(.settings) }
                        if let address = app.walletAddress {
                            SettingRow(symbol: "wallet.bifold", title: "Wallet address", sub: Fmt.short(address), accessory: .copy) { app.copy(address) }
                        }
                        SettingRow(symbol: "play.rectangle", title: "Replay the intro", sub: "The welcome screen you saw first") { confirmOnboarding = true }
                    }
                    .padding(.top, 14)

                    // The policy has to be reachable from inside the app. The welcome screen carries it
                    // too, but a signed-in account never sees that screen again.
                    KCard {
                        SettingRow(symbol: "hand.raised", title: "Privacy Policy", sub: "stonks247.fun/privacy") {
                            open("https://stonks247.fun/privacy")
                        }
                        SettingRow(symbol: "doc.plaintext", title: "Terms of Service", sub: "stonks247.fun/terms") {
                            open("https://stonks247.fun/terms")
                        }
                    }
                    .padding(.top, 12)

                    // Signing out is not navigation and does not belong in a stack of chevrons.
                    // Deleting the account sits with it: both are ways of leaving, and 5.1.1(v) is
                    // about the delete being easy to find, not about it being filed tidily.
                    KCard {
                        SettingRow(symbol: "rectangle.portrait.and.arrow.right", tint: Theme.red,
                                   title: "Sign out", sub: app.auth.accountLabel ?? "Signed in", accessory: .none, destructive: true) { confirmSignOut = true }
                        SettingRow(symbol: "trash", tint: Theme.red,
                                   title: "Delete account", sub: "Permanent. Your wallet stays on-chain.", accessory: .none, destructive: true) {
                            // What is in the wallet decides what the confirmation has to say, so it
                            // is worth a fresh read before asking.
                            Task {
                                if app.wallet == nil { await app.loadWallet(fresh: true) }
                                confirmDelete = true
                            }
                        }
                    }
                    .padding(.top, 12)
                    #if DEBUG
                    if Feature.debugTools {
                    SettingRow(symbol: "bell", title: "Preview toasts", sub: "Success, then error") {
                        app.show("You own 0.109 NVDAx")
                        Task { try? await Task.sleep(for: .seconds(2.6)); app.show("Price moved. Nothing was charged.", error: true) }
                    }
                    SettingRow(symbol: "ladybug", title: "Copy /v1/me response", sub: app.auth.me.map { "status: \($0.status)" } ?? app.auth.meRaw.map { String($0.prefix(60)) } ?? "not loaded yet") {
                        Task { await app.auth.refreshMe(); app.copy(app.auth.meRaw ?? "no response") }
                    }
                    }
                    #endif
                    Text(Self.version)
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity).padding(.top, 28)
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .appDialog("Replay the intro?", isPresented: $confirmOnboarding,
                   message: "Nothing about your account changes.", confirm: "Show it") {
            app.replayingIntro = true; app.path.removeAll()
        }
        .appDialog("Sign out?", isPresented: $confirmSignOut,
                   message: "Your wallet stays with your account. Sign back in any time.", confirm: "Sign out", destructive: true) {
            Task { await app.signOut() }
        }
        .appDialog("Delete account?", isPresented: $confirmDelete,
                   message: deleteWarning, confirm: heldUsd >= 0.01 ? "Delete anyway" : "Delete", destructive: true) {
            Task { await app.deleteAccount() }
        }
        .alert("Your handle", isPresented: $editingHandle) {
            TextField("a–z, 0–9, _", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save") { saveHandle() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(handleError ?? "3–20 characters: letters, numbers, underscore.") }
    }

    /// The screen's own header — the tab bar already says "You", and a grey circle with a
    /// single grey letter in it was the most template-looking thing on the screen.
    private var identity: some View {
        Button { handle = app.auth.me?.handle ?? ""; handleError = nil; editingHandle = true } label: {
            HStack(spacing: 14) {
                Text(String((app.auth.me?.handle ?? app.auth.accountLabel ?? "?").prefix(1)).uppercased())
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(skin.accent)
                    .frame(width: 62, height: 62)
                    .background(skin.accentTint, in: .circle)
                    .overlay { Circle().stroke(skin.accent.opacity(0.35), lineWidth: 1) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.auth.me?.handle.map { "@" + $0 } ?? "Pick a handle")
                        .font(.system(size: 22, weight: .semibold)).tracking(-0.5)
                    Text([app.auth.accountLabel, app.auth.me?.createdAt.map { "since " + Fmt.date($0) }].compactMap { $0 }.joined(separator: " · "))
                        .font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                    .frame(width: 30, height: 30)
                    .background(Theme.surface, in: .circle)
                    .overlay { Circle().stroke(Theme.line, lineWidth: 1) }
            }
            .padding(.vertical, 6).contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }

    private func open(_ url: String) {
        if let u = URL(string: url) { openURL(u) }
    }

    private var heldUsd: Double { app.wallet?.totalUsd ?? 0 }

    /// Deleting the account deletes the Privy login, and that login is the only way into the wallet.
    /// The app has no withdraw and no key export, so for a funded wallet this is not "your funds stay
    /// on-chain" — it is losing them. Say the number out loud rather than a reassuring generality.
    private var deleteWarning: String {
        heldUsd >= 0.01
            ? "This wallet holds \(Fmt.usd(heldUsd)). Deleting your account deletes the login that opens it, and we cannot move those funds out for you — sell and withdraw first, or they are gone."
            : "This deletes your account and signs you out. It cannot be undone."
    }

    private static var version: String {
        let b = Bundle.main.infoDictionary
        let v = b?["CFBundleShortVersionString"] as? String ?? "0"
        let n = b?["CFBundleVersion"] as? String ?? "0"
        return "Stonks247 \(v) (\(n))"
    }

    private func saveHandle() {
        let h = handle.lowercased().trimmingCharacters(in: .whitespaces)
        guard h.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else { handleError = "3–20 characters: letters, numbers, underscore."; editingHandle = true; return }
        Task {
            do { app.auth.applyMe(try await API.shared.patchMe(handle: h)); app.show("@\(h) is yours") }
            catch APIError.http(409, _) { handleError = "That handle is taken."; editingHandle = true }
            catch { app.show(TradeStore.message(error)) }
        }
    }
}

/// A settings line: glyph in a fixed leading column, title over subtitle, accessory on the
/// right. There is deliberately no chip behind the glyph — a grey rounded square around every
/// icon turns four different actions into one repeated shape, and that sameness is what made
/// this screen read as a template rather than a product.
struct SettingRow: View {
    enum Accessory { case chevron, copy, none }

    let symbol: String
    var tint: Color = Theme.muted
    let title: String
    let sub: String
    var accessory: Accessory = .chevron
    var destructive = false
    var trailing: AnyView? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(tint)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold)).tracking(-0.2)
                        .foregroundStyle(destructive ? Theme.red : Theme.ink)
                    Text(sub).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer(minLength: 8)
                if let trailing { trailing } else { accessoryView }
            }
            .padding(.vertical, 11).frame(minHeight: 58).contentShape(.rect)
        }
        .buttonStyle(RowPress())
    }

    @ViewBuilder private var accessoryView: some View {
        switch accessory {
        // The address row copies; a chevron would promise a page that is not there.
        case .copy: Image(systemName: "square.on.square").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.faint)
        case .chevron: Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
        case .none: EmptyView()
        }
    }
}
