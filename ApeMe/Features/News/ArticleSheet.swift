import SwiftUI
import SafariServices

/// The headline, the summary, and a way into the article — which lives on the publisher's site,
/// so it opens in Safari Reader inside ApeMe rather than kicking the user out to Safari.
struct ArticleSheet: View {
    let item: NewsItem
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var reading = false

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
            }
            .scrollIndicators(.hidden)
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
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $reading) {
            if let url = item.link { SafariReader(url: url).ignoresSafeArea() }
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

/// Safari with Reader on where the page supports it. The user taps Done and is back in ApeMe.
struct SafariReader: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.entersReaderIfAvailable = true
        let vc = SFSafariViewController(url: url, configuration: cfg)
        vc.preferredBarTintColor = UIColor(Theme.ground)
        vc.preferredControlTintColor = UIColor(Theme.ink)
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
