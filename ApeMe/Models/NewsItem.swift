import Foundation

/// One headline. The same shape comes back from the stock feed, the home feed and the ticker.
struct NewsItem: Codable, Hashable, Identifiable {
    let id: String
    let mint: String
    let symbol: String
    let name: String?
    let image: String?          // the stock's logo — always present
    let priceUsd: Double?
    let change24h: Double?
    let title: String
    let summary: String?
    let source: String
    let url: String
    let articleImage: String?   // a real photo, or nil once the BE strips outlet placeholders
    let publishedAt: Int?
    let impact: String?         // none | minor | material | major | critical, nullable
    let direction: String?      // bullish | bearish | neutral, nullable
    let confidence: Double?     // withheld below 0.5 server-side — never shown
    let tier1: Bool?

    var link: URL? { URL(string: url) }
    var logoURL: URL? { image.flatMap(URL.init(string:)) }
    var photoURL: URL? { articleImage.flatMap(URL.init(string:)) }

    /// Only material and worse earns a badge. "minor" is noise, "none" and nil say nothing.
    var impactBadge: String? {
        guard let impact, ["material", "major", "critical"].contains(impact) else { return nil }
        return impact
    }
}

struct NewsResponse: Codable { let items: [NewsItem] }
