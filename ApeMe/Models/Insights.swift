import Foundation

/// The brokerage half of a stock page: where Nasdaq closed, what the company is worth, when it
/// reports, and whether the token quietly pays a dividend. Pre-IPO names return the same shape
/// with `ticker` nil and everything below it null — render only what is non-nil.
struct Insights: Codable, Hashable {
    let mint: String
    let symbol: String
    let ticker: String?
    var market: Market?
    var nasdaq: Nasdaq?
    var premiumVsLastPct: Double?
    var stats: Stats?
    var company: Company?
    var earnings: Earnings?
    var dividends: Dividends?
    let asOf: Int?

    struct Market: Codable, Hashable {
        let isOpen: Bool?
        let session: String?        // "pre" | "open" | "post" | "closed"
        let rawSession: String?
        let holiday: String?
        let alwaysOn: Bool?

        var label: String {
            switch session {
            case "open": "Market open"
            case "pre": "Pre-market"
            case "post": "After hours"
            case "closed": "Closed"
            default: (isOpen ?? false) ? "Market open" : "Closed"
            }
        }
        var isLive: Bool { session == "open" }
    }

    /// `last` is the live print while the market trades, and yesterday's close once it shuts.
    /// `asOf` is the quote's timestamp, which is why it stops moving overnight.
    struct Nasdaq: Codable, Hashable {
        let last: Double?
        let change: Double?
        let changePct: Double?
        let open: Double?
        let high: Double?
        let low: Double?
        let prevClose: Double?
        let asOf: Int?
    }

    struct Stats: Codable, Hashable {
        let high52w: Double?
        let low52w: Double?
        let marketCapUsd: Double?
        let peTtm: Double?          // null whenever trailing EPS is negative
        let epsTtm: Double?
        let dividendYieldPct: Double?
        let beta: Double?
    }

    struct Company: Codable, Hashable {
        let name: String?
        let sector: String?
        let exchange: String?
        let website: String?
        let ipo: String?
        let logo: String?

        /// "Intel Corp" → "Intel", for a sentence rather than a filing.
        var shortName: String? {
            guard let name else { return nil }
            let trimmed = name.replacingOccurrences(
                of: #"\s+(Corp|Corporation|Inc|plc|Ltd|Co)\.?$"#,
                with: "", options: [.regularExpression, .caseInsensitive])
            return trimmed.isEmpty ? name : trimmed
        }
        var websiteURL: URL? { website.flatMap(URL.init(string:)) }
        var host: String? { websiteURL?.host()?.replacingOccurrences(of: "www.", with: "") }
    }

    struct Earnings: Codable, Hashable {
        let date: String?           // "2026-10-22"
        let when: String?           // "after close"
        let inDays: Int?
        let epsEstimate: Double?
        let quarter: Int?
        let year: Int?

        var day: Date? { date.flatMap { Self.parser.date(from: $0) } }
        private static let parser: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .gmt; return f
        }()
    }

    /// Backed's custodian reinvests the dividend and raises the token's rebasing multiplier, so the
    /// holder's balance grows on its own. Never surface a bare yield — show the growth.
    struct Dividends: Codable, Hashable {
        let mechanism: String?      // "rebase" on xStocks, nil elsewhere
        let yieldPct: Double?
        let multiplier: Double?
        let growthSinceLaunchPct: Double?

        var rebases: Bool { mechanism == "rebase" }
        var hasPaid: Bool { (growthSinceLaunchPct ?? 0) > 0 }
    }
}
