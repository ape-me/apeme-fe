import SwiftUI

struct YouView: View {
    @Environment(AppState.self) private var app
    @State private var confirmOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            Text("You").h1Text().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mode").h2Text()
                        HStack {
                            Text("Ape mode shows floors, kings and the live tape").font(.sub).foregroundStyle(Theme.muted)
                            Spacer()
                            ModeSwitch()
                        }
                        Text(app.isApe ? "Green. Floors, kings and the live tape up front." : "Blue. Stocks first, fair values, the calm view. Community tokens one tap away.")
                            .font(.sub).foregroundStyle(Theme.muted).padding(.top, 4)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Money").h2Text()
                        SettingRow(symbol: "plus", title: "Add money", sub: "Apple Pay, another chain, or send SOL") { app.sheet = .deposit }
                        SettingRow(symbol: nil, glyph: "◎", title: "Demo wallet",
                                   sub: app.demoWallet ? "\(Fmt.short(API.demoAddress)) · a real wallet from the tape" : "Signed out · Portfolio shows the empty state",
                                   trailing: AnyView(SwitchShape(on: app.demoWallet, tint: Skin(mode: app.mode ?? .invest).accent))) {
                            app.demoWallet.toggle()
                        }
                        SettingRow(symbol: "doc.on.doc", title: "Wallet address", sub: Fmt.short(API.demoAddress)) { app.copy(API.demoAddress) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App").h2Text()
                        SettingRow(symbol: "arrow.counterclockwise", title: "Show onboarding again", sub: "Three slides and the mode question") { confirmOnboarding = true }
                        SettingRow(symbol: "star", title: "Clear watchlist", sub: "\(app.watch.count) stocks · \(app.tokenWatch.count) tokens") {
                            app.watch = []; app.tokenWatch = []
                        }
                    }
                    Text("v0.1 · orders and funding are previews").font(.sub).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .confirmationDialog("Show onboarding again?", isPresented: $confirmOnboarding, titleVisibility: .visible) {
            Button("Show it") { app.mode = nil; app.path.removeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll pick a mode again. Nothing else changes.")
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
