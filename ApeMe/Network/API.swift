import Foundation

/// The phone talks only to ape-be. Every read goes through `fetch`, which returns the cached
/// copy when it is younger than `ttl` and refreshes in the background when it is older.
actor API {
    static let shared = API()
    static let base = URL(string: "https://apme-be.iamjoey.workers.dev/v1")!
    static let wsBase = "wss://apme-be.iamjoey.workers.dev/ws/"
    static let demoAddress = "CMCxpMHY2h9Zd5xQz91Fm2wpMdcHEmzBP9vUBbM1cthU"

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let cache = ResponseCache()
    private var inflight: [String: Task<Data, Error>] = [:]
    /// Identity token (when the Privy app has them enabled) and access token (always), from `Auth`.
    struct Tokens: Sendable { var identity: String?; var access: String? }
    private var tokenProvider: (@Sendable () async -> Tokens)?

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: cfg)
    }

    // MARK: Endpoints

    func stocks(issuer: String) async throws -> StocksResponse {
        let r: StocksResponse = try await fetch("/stocks?issuer=\(issuer)", ttl: 5); return r.visible
    }
    func stocks(mints: [String]) async throws -> StocksResponse {
        let r: StocksResponse = try await fetch("/stocks?mints=\(mints.joined(separator: ","))", ttl: 5); return r.visible
    }
    func stock(_ mint: String, fresh: Bool = false) async throws -> Stock {
        try await fetch("/stocks/\(mint)", ttl: fresh ? 0 : 5)
    }
    func history(_ mint: String, range: HistoryRange, fresh: Bool = false) async throws -> HistoryResponse {
        try await fetch("/stocks/\(mint)/history?range=\(range.api)", ttl: fresh ? 0 : 30)
    }
    func floorTokens(_ mint: String, sort: FloorSort, cursor: String? = nil, limit: Int = 40) async throws -> StockTokensResponse {
        var p = "/stocks/\(mint)/tokens?sort=\(sort.rawValue)&limit=\(limit)"
        if let cursor { p += "&cursor=\(cursor)" }
        return try await fetch(p, ttl: 5)
    }
    func newTokens(limit: Int = 30) async throws -> TokensResponse {
        try await fetch("/tokens?column=new&limit=\(limit)", ttl: 5)
    }
    func tokens(mints: [String]) async throws -> TokensResponse {
        try await fetch("/tokens?mints=\(mints.joined(separator: ","))", ttl: 5)
    }
    func token(_ mint: String, fresh: Bool = false) async throws -> TokenHeader {
        try await fetch("/tokens/\(mint)", ttl: fresh ? 0 : 3)
    }
    func candles(_ mint: String, tf: Timeframe, limit: Int = 120) async throws -> CandlesResponse {
        try await fetch("/tokens/\(mint)/candles?tf=\(tf.rawValue)&limit=\(limit)", ttl: 10)
    }
    func trades(_ mint: String, limit: Int = 40) async throws -> TradesResponse {
        try await fetch("/tokens/\(mint)/trades?limit=\(limit)", ttl: 3)
    }
    /// Nasdaq, company, earnings and the token's dividend rebase. Cached 5 min on the BE.
    func insights(_ mint: String) async throws -> Insights {
        try await fetch("/stocks/\(mint)/insights", ttl: 300)
    }
    /// A stock's own headlines. `before` is the previous page's oldest `publishedAt`.
    func stockNews(_ mint: String, limit: Int = 5, before: Int? = nil) async throws -> NewsResponse {
        var p = "/stocks/\(mint)/news?limit=\(limit)"
        if let before { p += "&before=\(before)" }
        let r: NewsResponse = try await fetch(p, ttl: 60); return r.visible
    }
    /// The Home feed, newest-first. With `mints`, those stocks come first. `perStock` caps how
    /// many headlines one company may take (BE default 3), and `minImpact` filters by score —
    /// `material` with `perStock: 1` is what the headline strip runs on.
    func news(mints: [String] = [], limit: Int = 30, before: Int? = nil,
              minImpact: String? = nil, perStock: Int? = nil) async throws -> NewsResponse {
        var p = "/news?limit=\(limit)"
        if !mints.isEmpty { p += "&mints=\(mints.joined(separator: ","))" }
        if let before { p += "&before=\(before)" }
        if let minImpact { p += "&minImpact=\(minImpact)" }
        if let perStock { p += "&perStock=\(perStock)" }
        let r: NewsResponse = try await fetch(p, ttl: 60); return r.visible
    }
    func collections() async throws -> CollectionsResponse {
        let r: CollectionsResponse = try await fetch("/collections", ttl: 30); return r.visible
    }
    func movers(limit: Int = 5) async throws -> MoversResponse {
        let r: MoversResponse = try await fetch("/movers?limit=\(limit)", ttl: 15); return r.visible
    }
    func wallet(_ address: String, activity: Int = 30, fresh: Bool = false, bustCache: Bool = false) async throws -> Wallet {
        // `bustCache` → `fresh=1`: the BE skips its edge cache. Once after a confirmed trade, and on pull-to-refresh.
        try await fetch("/wallet/\(address)?activity=\(activity)\(bustCache ? "&fresh=1" : "")", ttl: fresh ? 0 : 3)
    }
    func ticker(memes: Int = 10, stonks: Int = 1) async throws -> TickerResponse {
        try await fetch("/ticker?memes=\(memes)&stonks=\(stonks)", ttl: 30)
    }

    // MARK: Account (signed in; `privy-id-token` goes on every request)

    /// Creates the user on first call. `raw` is the untouched JSON for debugging the token shape.
    func me() async throws -> Data {
        try await send("GET", "/me")
    }

    func redeemInvite(_ code: String) async throws -> InviteResponse {
        try decoder.decode(InviteResponse.self, from: try await send("POST", "/me/invite", body: ["code": code]))
    }
    func patchMe(handle: String? = nil, avatarUrl: String? = nil) async throws -> Me {
        var b: [String: Any] = [:]
        if let handle { b["handle"] = handle }
        if let avatarUrl { b["avatarUrl"] = avatarUrl }
        return try decoder.decode(Me.self, from: try await send("PATCH", "/me", body: b))
    }

    // Wallets
    func myWallets() async throws -> WalletsResponse { try decoder.decode(WalletsResponse.self, from: try await send("GET", "/me/wallets")) }
    func patchWallet(_ address: String, label: String? = nil, isDefault: Bool? = nil) async throws -> WalletsResponse {
        var b: [String: Any] = [:]
        if let label { b["label"] = label }
        if let isDefault { b["isDefault"] = isDefault }
        return try decoder.decode(WalletsResponse.self, from: try await send("PATCH", "/me/wallets/\(address)", body: b))
    }

    // Settings
    func settings() async throws -> Me.Settings { try decoder.decode(Me.Settings.self, from: try await send("GET", "/me/settings")) }
    func patchSettings(_ patch: [String: Any]) async throws -> Me.Settings { try decoder.decode(Me.Settings.self, from: try await send("PATCH", "/me/settings", body: patch)) }

    // Referrals
    func referrals() async throws -> Referrals { try decoder.decode(Referrals.self, from: try await send("GET", "/me/referrals")) }
    func claimReferrals() async throws -> ClaimResponse { try decoder.decode(ClaimResponse.self, from: try await send("POST", "/me/referrals/claim", body: [:])) }

    // Watchlist
    func watchlist() async throws -> StocksResponse { try decoder.decode(StocksResponse.self, from: try await send("GET", "/me/watchlist")) }
    func watch(_ mint: String, on: Bool) async throws { _ = try await send(on ? "PUT" : "DELETE", "/me/watchlist/\(mint)") }

    // MARK: Trading

    func quote(inputMint: String, outputMint: String, amountRaw: String, taker: String, priority: String, slippageBps: Int? = nil) async throws -> Quote {
        var b: [String: Any] = ["inputMint": inputMint, "outputMint": outputMint, "amount": amountRaw, "taker": taker, "priority": priority]
        if let slippageBps { b["slippageBps"] = slippageBps }
        return try decoder.decode(Quote.self, from: try await send("POST", "/swap/quote", body: b))
    }
    func submit(requestId: String, signedTransaction: String) async throws -> SubmitResponse {
        try decoder.decode(SubmitResponse.self, from: try await send("POST", "/swap/submit", body: ["requestId": requestId, "signedTransaction": signedTransaction]))
    }
    func tx(_ signature: String) async throws -> TxStatus {
        try decoder.decode(TxStatus.self, from: try await send("GET", "/tx/\(signature)"))
    }

    /// Uncached request with an optional JSON body. Used for everything under /me and for trades.
    private func send(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> Data {
        var req = URLRequest(url: URL(string: API.base.absoluteString + path)!)
        req.httpMethod = method
        await authorize(&req)
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let resp: URLResponse
        do { (data, resp) = try await session.data(for: req) } catch { throw APIError.transport(error) }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let body = try? decoder.decode(ErrorBody.self, from: data)
            if body?.error == "insufficient_usdc" { throw APIError.insufficientFunds(shortUsd: body?.shortUsd ?? 0) }
            var msg = body?.error ?? "request failed"
            if let rid = body?.requestId ?? (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "cf-ray") { msg += " · req \(rid)" }
            throw APIError.http(code, msg)
        }
        return data
    }

    func setTokenProvider(_ p: @escaping @Sendable () async -> Tokens) { tokenProvider = p }

    private func authorize(_ req: inout URLRequest) async {
        guard let t = await tokenProvider?() else { return }
        if let id = t.identity { req.setValue(id, forHTTPHeaderField: "privy-id-token") }
        if let a = t.access { req.setValue("Bearer \(a)", forHTTPHeaderField: "Authorization") }
    }

    // MARK: Cached copy for instant first paint

    func cached<T: Decodable>(_ path: String, as: T.Type = T.self) async -> T? {
        guard let e = await cache.get(path) else { return nil }
        return try? decoder.decode(T.self, from: e.data)
    }

    // MARK: Core

    private func fetch<T: Decodable>(_ path: String, ttl: TimeInterval) async throws -> T {
        if ttl > 0, let e = await cache.get(path) {
            if Date.now.timeIntervalSince(e.at) < ttl, let v = try? decoder.decode(T.self, from: e.data) {
                return v
            }
        }
        do {
            let data = try await load(path)
            return try decoder.decode(T.self, from: data)
        } catch let err as APIError {
            // Offline or a 5xx: serve the last good copy rather than an empty screen.
            if case .http(let code, _) = err, code < 500 { throw err }
            if let e = await cache.get(path), let v = try? decoder.decode(T.self, from: e.data) { return v }
            throw err
        } catch let e as DecodingError {
            throw APIError.decoding(e)
        }
    }

    private func load(_ path: String) async throws -> Data {
        if let t = inflight[path] { return try await t.value }
        let task = Task<Data, Error> {
            let url = URL(string: API.base.absoluteString + path)!
            var req = URLRequest(url: url)
            await authorize(&req)
            let data: Data
            let resp: URLResponse
            do { (data, resp) = try await session.data(for: req) } catch { throw APIError.transport(error) }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                let body = try? decoder.decode(ErrorBody.self, from: data)
                if body?.error == "insufficient_usdc" { throw APIError.insufficientFunds(shortUsd: body?.shortUsd ?? 0) }
                let msg = body?.error ?? "request failed"
                throw APIError.http(code, msg)
            }
            await cache.set(path, data)
            return data
        }
        inflight[path] = task
        defer { inflight[path] = nil }
        return try await task.value
    }
}
