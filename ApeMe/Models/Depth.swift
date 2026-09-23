import Foundation

/// What a given order size costs you in price, straight from the pool. Turns "very large orders
/// move the price" into a number the user can size against.
struct Depth: Codable, Hashable {
    struct Level: Codable, Hashable, Identifiable {
        let usd: Double
        /// nil means no route at that size at all.
        let impactPct: Double?
        var id: Double { usd }

        /// Neutral under 1%, amber to 3%, red past it — the same bands as everywhere else.
        var isThin: Bool { (impactPct ?? 0) > 1 }
    }
    let mint: String
    let symbol: String?
    let levels: [Level]
    let asOf: Int?

    /// The $1k rung is the one worth a sentence — it's the size a real first order reaches.
    var notable: Level? { levels.first { $0.usd >= 1000 && ($0.impactPct ?? 0) > 1 } }
}
