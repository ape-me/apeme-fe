import Foundation
import Observation
import PrivySDK

/// Privy login + embedded Solana wallet. One instance for the app; `AppState` reads `address`.
@Observable @MainActor
final class Auth {
    static let shared = Auth()

    static let appId = "cmubdpllu01d00cl2p2q2n6h6"
    static let clientId = "client-WY6dwtnFJ1tfTakEeB1yNpEKTvshPSvbYa6DP2h7Cohay"
    static let urlScheme = "apeme"

    private let privy: any Privy
    private(set) var user: (any PrivyUser)?
    /// All embedded Solana wallets, in Privy order (hdIndex). `address` is the active one.
    private(set) var wallets: [any EmbeddedSolanaWallet] = []
    private(set) var address: String? { didSet { UserDefaults.standard.set(address, forKey: "apeme.activeAddress") } }
    private(set) var me: Me?
    var settings: Me.Settings { me?.settings ?? .defaults }
    /// True once `/v1/me` has been tried at least once for this session (success or not).
    private(set) var meTried = false
    /// Untouched `/v1/me` JSON, for confirming the token shape with the backend.
    private(set) var meRaw: String?
    private(set) var ready = false

    var needsInvite: Bool { me?.needsInvite ?? false }

    /// Sent as `privy-id-token` on every call to ape-be.
    var identityToken: String? { user?.identityToken }

    /// Both tokens for the API layer. Access token is fetched fresh (the SDK refreshes it).
    func tokens() async -> API.Tokens {
        guard let user else { return API.Tokens() }
        return API.Tokens(identity: user.identityToken, access: try? await user.getAccessToken())
    }

    /// "you@x.com" or "Apple" — whatever the user signed in with.
    var accountLabel: String? {
        guard let user else { return nil }
        for a in user.linkedAccounts {
            switch a {
            case .email(let e): return e.email
            case .apple: return "Apple"
            default: continue
            }
        }
        return "Signed in"
    }

    private init() {
        privy = PrivySdk.initialize(config: PrivyConfig(appId: Self.appId, appClientId: Self.clientId))
        Task { await API.shared.setTokenProvider { await Auth.shared.tokens() } }
        Task { await restore() }
    }

    func restore() async {
        if case .authenticated(let u) = await privy.getAuthState() { await signedIn(u) }
        ready = true
    }

    // MARK: Login

    func loginWithApple() async throws {
        do {
            let u = try await privy.oAuth.login(with: .apple, appUrlScheme: Self.urlScheme)
            await signedIn(u)
        } catch {
            // Privy occasionally fails to fetch Apple's JWKS while verifying the token. One quiet retry.
            guard "\(error)".contains("JWKS") else { throw error }
            let u = try await privy.oAuth.login(with: .apple, appUrlScheme: Self.urlScheme)
            await signedIn(u)
        }
    }

    func sendCode(to email: String) async throws {
        try await privy.email.sendCode(to: email)
    }

    func loginWithCode(_ code: String, email: String) async throws {
        let u = try await privy.email.loginWithCode(code, sentTo: email)
        await signedIn(u)
    }

    func logout() async {
        await user?.logout()
        user = nil
        wallets = []
        address = nil
        me = nil
        meRaw = nil
        meTried = false
    }

    // MARK: Account

    /// `/v1/me` after login; decides whether the invite screen is needed.
    @discardableResult
    func refreshMe() async -> Me? {
        defer { meTried = true }
        var raw = ""
        do {
            let data = try await API.shared.me()
            raw = String(decoding: data, as: UTF8.self)
            meRaw = raw
            me = try JSONDecoder().decode(Me.self, from: data)
        } catch {
            let t = await tokens()
            meRaw = raw.isEmpty ? "ERROR \(error) · idToken=\(t.identity == nil ? "nil" : "present") accessToken=\(t.access == nil ? "nil" : "present")" : "DECODE \(error)\n\(raw)"
        }
        #if DEBUG
        print("[apeme] /v1/me →", meRaw ?? "")
        #endif
        return me
    }

    func redeemInvite(_ code: String) async throws {
        _ = try await API.shared.redeemInvite(code.trimmingCharacters(in: .whitespacesAndNewlines))
        await refreshMe()
    }

    // MARK: Wallet

    private func signedIn(_ u: any PrivyUser) async {
        user = u
        // No-op when a wallet already exists.
        if u.embeddedSolanaWallets.isEmpty { _ = try? await u.createSolanaWallet() }
        wallets = u.embeddedSolanaWallets
        let saved = UserDefaults.standard.string(forKey: "apeme.activeAddress")
        address = wallets.first { $0.address == saved }?.address ?? wallets.first?.address
        await refreshMe()
    }

    /// The Privy wallet object for the active account; `provider` signs.
    var activeWallet: (any EmbeddedSolanaWallet)? { wallets.first { $0.address == address } }

    func switchAccount(_ addr: String) { if wallets.contains(where: { $0.address == addr }) { address = addr } }

    /// "+ New account": another HD wallet on the same user. `allowAdditional` is the SDK's flag.
    func createAdditionalWallet() async throws -> String {
        guard let user else { throw APIError.http(401, "unauthorized") }
        let w = try await user.createSolanaWallet(allowAdditional: true)
        wallets = user.embeddedSolanaWallets
        await refreshMe()
        return w.address
    }

    func applyMe(_ m: Me) { me = m }
    func applySettings(_ s: Me.Settings) {
        guard let m = me else { return }
        me = Me(userId: m.userId, handle: m.handle, avatarUrl: m.avatarUrl, status: m.status, wallets: m.wallets, settings: s, referral: m.referral, createdAt: m.createdAt, channel: m.channel)
    }
}
