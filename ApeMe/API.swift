import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): "\(code): \(msg)"
        case .transport(let e): e.localizedDescription
        }
    }
}

/// The phone talks only to ape-be. Reads are edge-cached 2–5s server side.
actor API {
    static let shared = API()
    static let base = URL(string: "https://apme-be.iamjoey.workers.dev")!
    static let wsBase = "wss://apme-be.iamjoey.workers.dev"

    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = true
        session = URLSession(configuration: cfg)
    }

    func stocks() async throws -> StocksResponse {
        try await get("/v1/stocks")
    }

    func tokens(stock: String, sort: Sort, cursor: String? = nil, limit: Int = 50) async throws -> StockTokensResponse {
        var q = [URLQueryItem(name: "sort", value: sort.rawValue), URLQueryItem(name: "limit", value: String(limit))]
        if let cursor { q.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await get("/v1/stocks/\(stock)/tokens", query: q)
    }

    func token(_ mint: String) async throws -> TokenHeader {
        try await get("/v1/tokens/\(mint)")
    }

    func candles(_ mint: String, tf: Timeframe, limit: Int = 300) async throws -> CandlesResponse {
        try await get("/v1/tokens/\(mint)/candles", query: [
            URLQueryItem(name: "tf", value: tf.rawValue), URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func trades(_ mint: String, limit: Int = 100) async throws -> TradesResponse {
        try await get("/v1/tokens/\(mint)/trades", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(url: API.base.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        let data: Data
        let resp: URLResponse
        do { (data, resp) = try await session.data(from: comps.url!) } catch { throw APIError.transport(error) }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = (try? decoder.decode(ErrorBody.self, from: data))?.error ?? "request failed"
            throw APIError.http(code, msg)
        }
        return try decoder.decode(T.self, from: data)
    }
}
