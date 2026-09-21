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
    private var tokenProvider: (@Sendable () async -> String?)?

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: cfg)
    }

    // MARK: Endpoints

    func stocks(issuer: String) async throws -> StocksResponse {
        try await fetch("/stocks?issuer=\(issuer)", ttl: 5)
    }
    func stocks(mints: [String]) async throws -> StocksResponse {
        try await fetch("/stocks?mints=\(mints.joined(separator: ","))", ttl: 5)
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
    func collections() async throws -> CollectionsResponse {
        try await fetch("/collections", ttl: 30)
    }
    func movers(limit: Int = 5) async throws -> MoversResponse {
        try await fetch("/movers?limit=\(limit)", ttl: 15)
    }
    func wallet(_ address: String, activity: Int = 30) async throws -> Wallet {
        try await fetch("/wallet/\(address)?activity=\(activity)", ttl: 5)
    }
    func ticker(memes: Int = 10, stonks: Int = 1) async throws -> TickerResponse {
        try await fetch("/ticker?memes=\(memes)&stonks=\(stonks)", ttl: 30)
    }

    /// Who am I, per ape-be. Needs a signed-in user; the identity token goes in the header.
    func me() async throws -> String {
        String(decoding: try await load("/me"), as: UTF8.self)
    }

    func setTokenProvider(_ p: @escaping @Sendable () async -> String?) { tokenProvider = p }

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
            if let token = await tokenProvider?() { req.setValue(token, forHTTPHeaderField: "privy-id-token") }
            let data: Data
            let resp: URLResponse
            do { (data, resp) = try await session.data(for: req) } catch { throw APIError.transport(error) }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else {
                let msg = (try? decoder.decode(ErrorBody.self, from: data))?.error ?? "request failed"
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
