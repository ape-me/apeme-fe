import SwiftUI

/// Add money: Apple Pay first, then bridge, then send SOL.
struct DepositSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Add money").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            VStack(spacing: 0) {
                row("Pay", "Apple Pay", "Card on file, no wallet needed", tag: "New") { dismiss(); app.show("Apple Pay opens here in the app") }
                row("↗", "From another chain", "Ethereum, Base, Arbitrum and 10+ more") { dismiss(); app.show("Bridge opens here in the app") }
                row("↓", "Send SOL or USDC", "Address and QR code") { dismiss(); app.copy(API.demoAddress) }
            }
            Text("Funding connects through Privy in the shipped app.").font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .presentationDetents([.height(340)])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }

    private func row(_ icon: String, _ title: String, _ sub: String, tag: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon).font(.system(size: 12, weight: .bold)).frame(width: 40, height: 40).background(Theme.surface2, in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(title).font(.rowTitle)
                        if let tag { Badge(text: tag, style: .accent) }
                    }
                    Text(sub).font(.sub).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 8).frame(minHeight: 64).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
