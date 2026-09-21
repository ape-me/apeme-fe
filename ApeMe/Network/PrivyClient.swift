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
    private(set) var address: String?
    private(set) var me: Me?
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
        let u = try await privy.oAuth.login(with: .apple, appUrlScheme: Self.urlScheme)
        await signedIn(u)
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
        address = nil
        me = nil
        meRaw = nil
    }

    // MARK: Account

    /// `/v1/me` after login; decides whether the invite screen is needed.
    @discardableResult
    func refreshMe() async -> Me? {
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
        let w = (try? await u.createSolanaWallet()) ?? u.embeddedSolanaWallets.first
        address = w?.address
        await refreshMe()
    }
}
