import Foundation

/// Assets that must never reach the screen, whatever the API sends back. The feed is not a
/// hard-coded stock list: everything else renders exactly as the BE returns it, and this is the one
/// deny-list, applied at the API boundary so no screen has to remember it.
///
/// What it excludes is *other issuers'* pre-IPO tokens — xStocks `SPCXx`, Backpack `SPCX` and Ondo
/// `SPCXon` — which the PreStocks bounty rule bans. PreStocks' own `SPACEX` (mint `PreANxu…`) is the
/// intended one and renders like OPENAI and ANTHROPIC, which come from the same issuer. The BE
/// excludes all three by mint at source; this stays as belt and braces, and it has been needed
/// once already, when a rename turned `SPCXX` into `SPACEX` and walked it back onto the screen.
enum Hidden {
    static let symbols: Set<String> = ["SPCXX", "SPCX", "SPCXON"]

    static func allows(_ symbol: String) -> Bool { !symbols.contains(symbol.uppercased()) }

    static func allows(_ stock: Stock) -> Bool {
        guard allows(stock.symbol) else { return false }
        if let u = stock.underlying, !allows(u) { return false }
        return true
    }

    static func filter(_ stocks: [Stock]) -> [Stock] { stocks.filter { allows($0) } }
    static func filter(_ stocks: [Stock]?) -> [Stock]? { stocks.map(filter) }
    /// A headline carries no `underlying`, so SPCXon has to be caught by its own symbol here
    /// rather than by the underlying that catches it in a stock list.
    static func filter(_ items: [NewsItem]) -> [NewsItem] { items.filter { allows($0.symbol ?? "") } }
}
