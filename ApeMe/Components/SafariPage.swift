import SwiftUI
import SafariServices

/// An in-app browser for pages the user comes back from. News articles deliberately open in the
/// real browser instead — this is for round trips, where a Done button beats leaving the app.
///
/// It also matters that SFSafariViewController runs out of process: Stonks247 cannot read or script
/// what happens inside it, which is the property you want when the page on the other side is asking
/// for a login and handing back a private key.
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
