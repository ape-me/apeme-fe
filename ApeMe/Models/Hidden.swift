import Foundation

/// Assets that must never reach the screen, whatever the API sends back. The feed is not a
/// hard-coded stock list: everything else renders exactly as the BE returns it, and this is the one
/// deny-list, applied at the API boundary so no screen has to remember it.
///
/// What it excludes is *other issuers'* pre-IPO tokens — xStocks `SPCXx` and Backpack `SPCX` — which
/// the PreStocks bounty rule bans. PreStocks' own `SPACEX` (mint `PreANxu…`) is the intended one and
/// renders like OPENAI and ANTHROPIC, which come from the same issuer. The BE excludes the other two
/// by mint at source; this stays as belt and braces.
enum Hidden {
    static let symbols: Set<String> = ["SPCXX", "SPCX", "SPCXON"]
    /// A mint cannot be renamed, which is the one thing a symbol has already proved it can do.
    static let mints: Set<String> = ["wzAyQTorWyoVXuJKj2x8EqKEGJpS13z6EWE9z5Aondo"]

    static func allows(_ symbol: String) -> Bool { !symbols.contains(symbol.uppercased()) }
    static func allows(mint: String?) -> Bool { !(mint.map(mints.contains) ?? false) }

    static func allows(_ stock: Stock) -> Bool {
        guard allows(mint: stock.mint), allows(stock.symbol) else { return false }
        if let u = stock.underlying, !allows(u) { return false }
        return true
    }

    static func filter(_ stocks: [Stock]) -> [Stock] { stocks.filter { allows($0) } }
    static func filter(_ stocks: [Stock]?) -> [Stock]? { stocks.map(filter) }
    /// A headline carries no `underlying`, so the symbol check that catches SPCXon in a stock list
    /// would miss it here. The mint is the only field both shapes share and cannot rename.
    static func filter(_ items: [NewsItem]) -> [NewsItem] {
        items.filter { allows(mint: $0.mint) && allows($0.symbol ?? "") }
    }
}
