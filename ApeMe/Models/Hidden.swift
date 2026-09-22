import Foundation

/// Assets that must never reach the screen, whatever the API sends back. The BE excludes SPCXX
/// at source as of 2f8c8f22, so this is a guard rather than the mechanism — it costs nothing and
/// the rule it enforces is absolute. The feed is not a hard-coded stock list: everything else
/// renders exactly as the BE returns it, and this is the one deny-list, applied at the API
/// boundary so no screen has to remember it.
enum Hidden {
    static let symbols: Set<String> = ["SPCXX"]

    static func allows(_ symbol: String) -> Bool { !symbols.contains(symbol.uppercased()) }

    static func filter(_ stocks: [Stock]) -> [Stock] { stocks.filter { allows($0.symbol) } }
    static func filter(_ stocks: [Stock]?) -> [Stock]? { stocks.map(filter) }
    static func filter(_ items: [NewsItem]) -> [NewsItem] { items.filter { allows($0.symbol) } }
}
