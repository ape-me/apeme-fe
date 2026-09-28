import Foundation

/// Assets that must never reach the screen, whatever the API sends back. The feed is not a
/// hard-coded stock list: everything else renders exactly as the BE returns it, and this is the one
/// deny-list, applied at the API boundary so no screen has to remember it.
///
/// It has already failed once. The BE excluded `SPCXX` at source, then the catalog update renamed
/// the same asset `SPACEX` and it came straight back through a guard that only knew the old
/// spelling. So this matches on every spelling we have seen and on the company name too — a rename
/// is exactly how a symbol deny-list goes quiet without anyone noticing.
enum Hidden {
    static let symbols: Set<String> = ["SPCXX", "SPACEX", "SPCX"]
    static let names: Set<String> = ["spacex", "space exploration technologies"]

    static func allows(_ symbol: String) -> Bool { !symbols.contains(symbol.uppercased()) }

    static func allows(_ stock: Stock) -> Bool {
        guard allows(stock.symbol) else { return false }
        guard !names.contains(stock.name.lowercased()) else { return false }
        if let u = stock.underlying, !allows(u) { return false }
        return true
    }

    static func filter(_ stocks: [Stock]) -> [Stock] { stocks.filter { allows($0) } }
    static func filter(_ stocks: [Stock]?) -> [Stock]? { stocks.map(filter) }
    static func filter(_ items: [NewsItem]) -> [NewsItem] { items.filter { allows($0.symbol) } }
}
