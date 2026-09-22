import SwiftUI

struct YouView: View {
    @Environment(AppState.self) private var app
    @State private var confirmOnboarding = false
    @State private var confirmSignOut = false
    @State private var editingHandle = false
    @State private var handle = ""
    @State private var handleError: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("You").h1Text().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Who you are
                    Button { handle = app.auth.me?.handle ?? ""; handleError = nil; editingHandle = true } label: {
                        HStack(spacing: 12) {
                            Text(String((app.auth.me?.handle ?? app.auth.accountLabel ?? "?").prefix(1)).uppercased())
                                .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.ink)
                                .frame(width: 56, height: 56).background(Theme.surface2, in: .circle)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.auth.me?.handle.map { "@" + $0 } ?? "Pick a handle").font(.system(size: 17, weight: .semibold))
                                Text([app.auth.accountLabel, app.auth.me?.createdAt.map { "since " + Fmt.dateTime($0) }].compactMap { $0 }.joined(separator: " · ")).font(.sub).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "pencil").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 8).contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    // Invite & earn
                    Button { app.push(.referrals) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("Invite & earn").h3Text(); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted) }
                            HStack(spacing: 4) {
                                Text(app.auth.me?.referral?.code ?? "——").font(.system(size: 22, weight: .semibold)).tracking(2).monospacedDigit()
                                Spacer()
                                Text("\(app.auth.me?.referral?.invitesLeft ?? 0) left · earned \(Fmt.usd(app.auth.me?.referral?.earnedUsd ?? 0))").font(.sub).monospacedDigit().foregroundStyle(Theme.muted)
                            }
                            Text("20% of ApeMe's fee on every trade they make, forever.").font(.sub).foregroundStyle(Theme.muted)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: .rect(cornerRadius: 16)).contentShape(.rect)
                    }
                    .buttonStyle(.plain).padding(.top, 12).padding(.bottom, 8)

                    SettingRow(symbol: app.isApe ? "flame" : "chart.line.uptrend.xyaxis", title: "Ape mode",
                               sub: app.isApe ? "Floors, kings and the live tape" : "Off · stocks and fair values",
                               trailing: AnyView(SwitchShape(on: app.isApe, tint: Skin(mode: app.mode ?? .invest).accent))) { app.toggleMode() }
                    SettingRow(symbol: "slider.horizontal.3", title: "Trading settings", sub: "Slippage, quick amounts, priority, confirmations") { app.push(.settings) }
                    if let address = app.walletAddress {
                        SettingRow(symbol: "doc.on.doc", title: "Wallet address", sub: Fmt.short(address)) { app.copy(address) }
                    }
                    SettingRow(symbol: "arrow.counterclockwise", title: "Show onboarding again", sub: "Three slides and the mode question") { confirmOnboarding = true }
                    SettingRow(symbol: "rectangle.portrait.and.arrow.right", title: "Sign out", sub: app.auth.accountLabel ?? "Signed in") { confirmSignOut = true }
                    #if DEBUG
                    SettingRow(symbol: "bell", title: "Preview toasts", sub: "Success, then error") {
                        app.show("You own 0.109 NVDAX")
                        Task { try? await Task.sleep(for: .seconds(2.6)); app.show("Price moved. Nothing was charged.", error: true) }
                    }
                    SettingRow(symbol: "ladybug", title: "Copy /v1/me response", sub: app.auth.me.map { "status: \($0.status)" } ?? app.auth.meRaw.map { String($0.prefix(60)) } ?? "not loaded yet") {
                        Task { await app.auth.refreshMe(); app.copy(app.auth.meRaw ?? "no response") }
                    }
                    #endif
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .appDialog("Show onboarding again?", isPresented: $confirmOnboarding,
                   message: "You'll pick a mode again. Nothing else changes.", confirm: "Show it") {
            app.onboarded = false; app.path.removeAll()
        }
        .appDialog("Sign out?", isPresented: $confirmSignOut,
                   message: "Your wallet stays with your account. Sign back in any time.", confirm: "Sign out", destructive: true) {
            Task { await app.signOut() }
        }
        .alert("Your handle", isPresented: $editingHandle) {
            TextField("a–z, 0–9, _", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save") { saveHandle() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(handleError ?? "3–20 characters: letters, numbers, underscore.") }
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

struct SettingRow: View {
    var symbol: String?
    var glyph: String? = nil
    let title: String
    let sub: String
    var trailing: AnyView? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let symbol { Image(systemName: symbol).font(.system(size: 16, weight: .medium)) }
                    else { Text(glyph ?? "").font(.system(size: 16, weight: .medium)) }
                }
                .frame(width: 40, height: 40).background(Theme.surface2, in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.rowTitle)
                    Text(sub).font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                }
                Spacer()
                if let trailing { trailing }
                else { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted) }
            }
            .padding(.vertical, 8).frame(minHeight: 64).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
