import Foundation

struct StocksResponse: Codable { let stocks: [Stock]; let asOf: Int? }
struct StockTokensResponse: Codable { let stock: Stock; let tokens: [TokenCard]; let next: String? }
struct TokensResponse: Codable { let tokens: [TokenCard]; let next: String? }
struct CandlesResponse: Codable { let mint: String; let tf: String; let candles: [Candle] }
struct TradesResponse: Codable { let mint: String; let trades: [Trade] }
struct HistoryResponse: Codable {
    let mint: String
    let range: String
    let points: [HistoryPoint]
    let changeAbs: Double?
    let changePct: Double?
}
struct CollectionsResponse: Codable { let collections: [StockCollection]; let asOf: Int? }
struct MoversResponse: Codable {
    let gainers: [Stock]?
    let losers: [Stock]?
    let mostTraded: [Stock]?
}
struct TickerResponse: Codable { let updatedAt: String?; let tokens: [TickerItem] }
struct ErrorBody: Codable { let error: String; let requestId: String? }
