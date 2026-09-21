import SwiftUI
import Observation

/// Mode, wallet, watchlists, navigation. Persisted bits go through UserDefaults directly so
/// observation still fires (`@AppStorage` does not work inside `@Observable`).
@Observable @MainActor
final class AppState {
    private let defaults = UserDefaults.standard

    var mode: Mode? { didSet { defaults.set(mode?.rawValue, forKey: "apeme.mode") } }
    /// Seen the slides and tapped Get started. Separate from `mode` so replaying onboarding never logs you out.
    var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "apeme.onboarded") } }
    var demoWallet: Bool { didSet { defaults.set(demoWallet, forKey: "apeme.demo"); if !demoWallet { wallet = nil } } }
    var watch: [String] { didSet { defaults.set(watch, forKey: "apeme.watch") } }
    var tokenWatch: [String] { didSet { defaults.set(tokenWatch, forKey: "apeme.tokenWatch") } }

    var tab: Tab = .home
    var path: [Route] = []
    var sheet: TradeSheet?
    var toast: String?
    var wallet: Wallet?
    var stocksByMint: [String: Stock] = [:]
    var online = true

    private var toastTask: Task<Void, Never>?

    init() {
        mode = defaults.string(forKey: "apeme.mode").flatMap(Mode.init(rawValue:))
        onboarded = defaults.bool(forKey: "apeme.onboarded")
        demoWallet = defaults.bool(forKey: "apeme.demo")
        watch = defaults.stringArray(forKey: "apeme.watch") ?? []
        tokenWatch = defaults.stringArray(forKey: "apeme.tokenWatch") ?? []
    }

    var isApe: Bool { mode == .ape }

    /// Privy wallet when signed in, the demo wallet when that's switched on, otherwise nothing.
    let auth = Auth.shared
    var signedIn: Bool { auth.user != nil }
    var walletAddress: String? { auth.address }
    var hasWallet: Bool { walletAddress != nil }
    /// Signed in but not yet let through the invite gate. Browsing works; trading opens the invite sheet.
    var needsInvite: Bool { signedIn && auth.needsInvite }

    func trade(_ s: TradeSheet) { sheet = s }

    // MARK: Navigation

    func root(_ t: Tab) {
        tab = t
        path.removeAll()
    }

    func push(_ r: Route) { path.append(r) }

    /// Stocks open the Stock page in Invest and the Floor in Ape.
    func openStock(_ mint: String) { push(isApe ? .floor(mint) : .stock(mint)) }

    func toggleMode() {
        mode = isApe ? .invest : .ape
        wallet = nil
        root(tab)
    }

    // MARK: Data

    func index(_ stocks: [Stock]) {
        for s in stocks { stocksByMint[s.mint] = s }
    }

    func loadWallet() async {
        guard let address = walletAddress else { wallet = nil; return }
        if let w = try? await API.shared.wallet(address, activity: 30) { wallet = w }
    }

    func signOut() async {
        await auth.logout()
        wallet = nil
        path.removeAll()
        tab = .home
    }

    // MARK: Watchlists

    func isWatching(_ mint: String) -> Bool { watch.contains(mint) }
    func toggleWatch(_ mint: String) {
        if let i = watch.firstIndex(of: mint) { watch.remove(at: i); show("Removed from watchlist") }
        else { watch.append(mint); show("Watching") }
    }
    func isWatchingToken(_ mint: String) -> Bool { tokenWatch.contains(mint) }
    func toggleTokenWatch(_ mint: String) {
        if let i = tokenWatch.firstIndex(of: mint) { tokenWatch.remove(at: i); show("Removed from watchlist") }
        else { tokenWatch.append(mint); show("Added to watchlist") }
    }

    // MARK: Feedback

    func show(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            if !Task.isCancelled { toast = nil }
        }
    }

    func copy(_ value: String) {
        UIPasteboard.general.string = value
        show("Copied to clipboard")
    }
}
