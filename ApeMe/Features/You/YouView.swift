import SwiftUI

struct YouView: View {
    @Environment(AppState.self) private var app
    @State private var confirmOnboarding = false
    @State private var confirmSignOut = false

    var body: some View {
        VStack(spacing: 0) {
            Text("You").h1Text().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingRow(symbol: app.isApe ? "flame" : "chart.line.uptrend.xyaxis", title: "Ape mode",
                               sub: app.isApe ? "Floors, kings and the live tape" : "Off · stocks and fair values",
                               trailing: AnyView(SwitchShape(on: app.isApe, tint: Skin(mode: app.mode ?? .invest).accent))) {
                        app.toggleMode()
                    }
                    if let address = app.walletAddress {
                        SettingRow(symbol: "doc.on.doc", title: "Wallet address", sub: Fmt.short(address)) { app.copy(address) }
                    }
                    SettingRow(symbol: "arrow.counterclockwise", title: "Show onboarding again", sub: "Three slides and the mode question") { confirmOnboarding = true }
                    if app.signedIn {
                        if app.needsInvite {
                            SettingRow(symbol: "ticket", title: "Enter invite code", sub: "Needed before your first trade") { app.sheet = .invite }
                        }
                        SettingRow(symbol: "rectangle.portrait.and.arrow.right", title: "Sign out", sub: app.auth.accountLabel ?? "Signed in") { confirmSignOut = true }
                        #if DEBUG
                        SettingRow(symbol: "ladybug", title: "Copy /v1/me response", sub: app.auth.me.map { "status: \($0.status)" } ?? app.auth.meRaw.map { String($0.prefix(60)) } ?? "not loaded yet") {
                            Task { await app.auth.refreshMe(); app.copy(app.auth.meRaw ?? "no response") }
                        }
                        #endif
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .confirmationDialog("Show onboarding again?", isPresented: $confirmOnboarding, titleVisibility: .visible) {
            Button("Show it") { app.onboarded = false; app.path.removeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll pick a mode again. Nothing else changes.")
        }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await app.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your wallet stays with your account. Sign back in any time.")
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
