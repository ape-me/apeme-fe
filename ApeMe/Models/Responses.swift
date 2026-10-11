import SwiftUI
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
struct HistoryResponse: Codable {
    let mint: String
    let range: String
    let points: [HistoryPoint]
    let changeAbs: Double?
    let changePct: Double?
    /// Stories that landed inside this range, each pinned to a chart point. Empty on LIVE.
    let events: [ChartEvent]?
}

/// A news story at the moment it came out, drawn as a dot on the price line.
struct ChartEvent: Codable, Hashable, Identifiable {
    let id: String
    /// The chart bucket the dot sits on.
    let t: Int
    let publishedAt: Int
    let title: String
    let source: String?
    let url: String
    /// material, major, critical.
    let impact: String
    /// bullish, bearish, neutral or null.
    let direction: String?
    /// Price change in the hour after the story; null while it is under an hour old.
    let moveAfterPct: Double?
    /// The outlet's square icon, for the token on the chart. Null falls back to a glyph.
    let sourceLogo: String?
    var link: URL? { URL(string: url) }
    var logoURL: URL? { sourceLogo.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
    var tint: Color {
        switch direction { case "bullish": Theme.green; case "bearish": Theme.red; default: Theme.faint }
    }
}
struct CollectionsResponse: Codable { let collections: [StockCollection]; let asOf: Int? }
struct MoversResponse: Codable {
    let gainers: [Stock]?
    let losers: [Stock]?
    let mostTraded: [Stock]?
}
struct ErrorBody: Codable {
    let error: String
    let requestId: String?
    /// Refusals carry the rule they enforced, so nothing has to be read back out of the sentence.
    let neededUsd: Double?
    let heldUsd: Double?
    let shortUsd: Double?
    let minUsd: Double?
    let excludedIssuers: [String]?
    /// 409 market_closed — the issuer's own hours, e.g. "Sunday 8pm ET".
    let opensAt: Int?
    /// 451 region_blocked.
    let country: String?
    /// 422 slippage — the band Jupiter would pick for this same trade, sized at the moment it
    /// refused. The retry offers this rather than a number the client invented.
    let suggestedSlippageBps: Int?
    /// no_route / rate_limited / upstream_error on a basket leg: which stock, and what Jupiter said.
    let symbol: String?
    let upstreamStatus: Int?
    /// 400 not_an_idea: three ideas that would work. 429 daily_limit: how many a day.
    let examples: [String]?
    let limit: Int?
}
