import SwiftUI

/// Invite & earn: code, share link, referred list, earnings and claim.
struct ReferralsView: View {
    @Environment(AppState.self) private var app
    @State private var r: Referrals?
    @State private var error: String?
    @State private var claiming = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BackButton(); Text("Invite & earn").h2Text(); Spacer() }.padding(.horizontal, 12).padding(.top, 6).frame(height: 56)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(r?.code ?? app.auth.me?.referral?.code ?? "——————").font(.system(size: 40, weight: .semibold)).tracking(4).monospacedDigit()
                        Text("\(r?.invitesLeft ?? app.auth.me?.referral?.invitesLeft ?? 0) invites left").font(.sub).foregroundStyle(Theme.muted)
                        Text("You earn 20% of Stonks247's fee on every trade they make, forever.").font(.system(size: 15)).foregroundStyle(Theme.ink)
                        HStack(spacing: 8) {
                            if let link = r?.link, let url = URL(string: link) {
                                ShareLink(item: url) { Pill(label: "Share link", icon: "square.and.arrow.up") {}.allowsHitTesting(false) }
                            }
                            Pill(label: "Copy code") { app.copy(r?.code ?? "") }
                        }
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: .rect(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Earnings").font(.system(size: 16, weight: .semibold)).tracking(-0.3)
                        KCard {
                            KV("Earned", Fmt.usd(r?.earnedUsd ?? 0))
                            KV("Claimable", Fmt.usd(r?.claimableUsd ?? 0))
                        }
                        let claimable = r?.claimableUsd ?? 0
                        BigButton(label: claiming ? "Claiming…" : "Claim \(Fmt.usd(claimable))", style: claimable >= 1 ? .white : .off) {
                            guard claimable >= 1, !claiming else { return }
                            claiming = true
                            Task { defer { claiming = false }
                                do { let c = try await API.shared.claimReferrals(); app.show("Sent \(Fmt.usd(c.amountUsd)) to your wallet"); await load() }
                                catch { self.error = TradeStore.message(error) } }
                        }
                        if claimable < 1 { Text("Claim from $1.").font(.sub).foregroundStyle(Theme.faint) }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("People you invited").font(.system(size: 16, weight: .semibold)).tracking(-0.3)
                        if let list = r?.referred, !list.isEmpty {
                            KCard { ForEach(list) { u in KV(u.handle.map { "@\($0)" } ?? Fmt.short(u.userId), "\(Fmt.usd(u.volumeUsd ?? 0)) traded") } }
                        } else { Text("Nobody yet. Share your code.").font(.sub).foregroundStyle(Theme.muted) }
                    }
                    if let p = r?.payouts, !p.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Payouts").font(.system(size: 16, weight: .semibold)).tracking(-0.3)
                            KCard { ForEach(p) { x in
                                KV(x.paidAt.map { Fmt.dateTime($0) } ?? "—") {
                                    Link(destination: URL(string: "https://solscan.io/tx/\(x.signature)")!) { Text("\(Fmt.usd(x.amountUsd)) ↗") }
                                }
                            } }
                        }
                    }
                    if let error { Text(error).font(.sub).foregroundStyle(Theme.red) }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .task { await load() }
    }

    private func load() async {
        do { r = try await API.shared.referrals() } catch { self.error = TradeStore.message(error) }
    }
}
