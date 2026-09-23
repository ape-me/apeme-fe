import Foundation

/// The rules for limit orders, read from the BE rather than assumed. `minUsd` moves from their
/// admin panel and `accountCostUsd` is computed from the live SOL price, so both drift without a
/// release — and `excludedIssuers` is what decides whether a stock offers limit orders at all,
/// so the day Jupiter supports transfer-fee mints the UI opens up on its own.
struct OrderConfig: Codable, Hashable {
    let minUsd: Double?
    let maxOpen: Int?
    let buyFeeBps: Int?
    let sellFeeBps: Int?
    let accountCostUsd: Double?
    let excludedIssuers: [String]?

    /// Used only until the real one arrives, and only to keep buttons sane on a cold launch.
    static let provisional = OrderConfig(minUsd: nil, maxOpen: nil, buyFeeBps: 150, sellFeeBps: 0,
                                         accountCostUsd: 0.48, excludedIssuers: nil)

    func allows(issuer: String) -> Bool {
        guard let excluded = excludedIssuers else { return true }
        return !excluded.contains(issuer)
    }
    var buyFeeRate: Double { Double(buyFeeBps ?? 150) / 10_000 }
}
