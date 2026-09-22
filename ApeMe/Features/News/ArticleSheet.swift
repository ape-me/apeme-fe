import SwiftUI
import SafariServices

/// The headline, the summary, and a way into the article — which lives on the publisher's site,
/// so it opens in Safari inside ApeMe rather than kicking the user out to another app.
struct ArticleSheet: View {
    let item: NewsItem
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var reading = false

    /// Plenty of headlines arrive with neither a summary nor a photo. A full-height sheet for
    /// three lines of text is the empty box the user saw, so the sheet sizes to what it holds.
    private var thin: Bool { (item.summary?.isEmpty ?? true) && item.photoURL == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if item.impactBadge != nil || item.direction != nil {
                        HStack(spacing: 6) {
                            if let i = item.impactBadge { NewsBadge.impact(i) }
                            if let d = item.direction { NewsBadge.direction(d) }
                        }
                    }
                    Text(item.title)
                        .font(.system(size: 22, weight: .semibold)).tracking(-0.4)
                        .lineSpacing(3).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let photo = item.photoURL {
                        RemoteImage(url: photo, fallback: "")
                            .frame(maxWidth: .infinity).frame(height: 190)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    if let summary = item.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 15)).lineSpacing(4).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if item.link != nil {
                        BigButton(label: "Read on \(item.source)", style: .ghost) { Haptic.light(); reading = true }
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 14).padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            BigButton(label: "Trade \(item.symbol)", style: .buy) {
                Haptic.medium()
                dismiss()
                app.openStock(item.mint)
                if let s = app.stocksByMint[item.mint] {
                    Task { try? await Task.sleep(for: .milliseconds(420)); app.trade(.buyStock(s)) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .presentationDetents(thin ? [.medium, .large] : [.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $reading) {
            if let url = item.link { SafariPage(url: url).ignoresSafeArea() }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Logo(url: item.logoURL, symbol: item.symbol, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.symbol).h3Text()
                    Text("\(item.source)\(item.publishedAt.map { " · \(Fmt.ago($0)) ago" } ?? "")")
                        .font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer()
            IconButton(symbol: "xmark", label: "Close") { dismiss() }
        }
        .padding(.top, 14)
    }
}

/// The publisher's page as they built it — no Reader. The user taps Done and is back in ApeMe.
struct SafariPage: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: cfg)
        vc.preferredBarTintColor = UIColor(Theme.ground)
        vc.preferredControlTintColor = UIColor(Theme.ink)
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
