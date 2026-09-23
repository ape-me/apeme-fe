import Foundation

struct StocksResponse: Codable { let stocks: [Stock]; let asOf: Int? }

/// Every list response drops the deny-listed assets as it is decoded, so nothing downstream —
/// stores, sections, search, the mint index — ever sees them.
extension StocksResponse { var visible: StocksResponse { .init(stocks: Hidden.filter(stocks), asOf: asOf) } }
extension CollectionsResponse {
    var visible: CollectionsResponse {
        .init(collections: collections.map { .init(id: $0.id, title: $0.title, tagline: $0.tagline, stocks: Hidden.filter($0.stocks)) }, asOf: asOf)
    }
}
extension MoversResponse {
    var visible: MoversResponse { .init(gainers: Hidden.filter(gainers), losers: Hidden.filter(losers), mostTraded: Hidden.filter(mostTraded)) }
}
extension NewsResponse { var visible: NewsResponse { .init(items: Hidden.filter(items)) } }
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
struct ErrorBody: Codable {
    let error: String
    let requestId: String?
    /// Only on `insufficient_usdc`, so the sheet can name the exact shortfall.
    let neededUsd: Double?
    let heldUsd: Double?
    let shortUsd: Double?
}
