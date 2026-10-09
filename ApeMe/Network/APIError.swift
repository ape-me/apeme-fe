import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    /// Carries the server's own arithmetic. "Not enough cash" on its own gives nobody — user or
    /// engineer — any way to tell a stale balance from a fee charged on top.
    case insufficientFunds(shortUsd: Double, neededUsd: Double?, heldUsd: Double?)
    /// The BE states the rule it enforced; the UI adopts it rather than guessing.
    case orderRefused(reason: String, minUsd: Double?, excludedIssuers: [String]?)
    /// The issuer is not quoting right now. Ondo runs Sunday 8pm to Friday 8pm ET.
    case marketClosed(opensAt: String?)
    /// Geo gate. Off during review, on at launch.
    case regionBlocked(country: String?)
    /// The price moved past the limit this quote was built with.
    case slippageExceeded(suggestedBps: Int?)
    /// The price source could not answer: no_route (Jupiter found nothing), rate_limited
    /// (Jupiter said 429) or upstream_error. `symbol` names the leg on a basket.
    case pricing(reason: String, symbol: String?, upstreamStatus: Int?)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): "\(code): \(msg)"
        case .insufficientFunds(let short, let needed, let held):
            "insufficient_usdc · short $\(short) · needs \(needed.map { "$\($0)" } ?? "?") · holds \(held.map { "$\($0)" } ?? "?")"
        case .orderRefused(let reason, _, _): reason
        case .marketClosed(let opensAt): "market_closed · opens \(opensAt ?? "later")"
        case .regionBlocked(let country): "region_blocked · \(country ?? "")"
        case .slippageExceeded(let bps): "slippage · suggests \(bps.map(String.init) ?? "?") bps"
        case .pricing(let reason, let symbol, let up): "\(reason)\(symbol.map { " · \($0)" } ?? "") · upstream \(up.map(String.init) ?? "?")"
        case .transport(let e): e.localizedDescription
        case .decoding: "Unexpected response"
        }
    }
}
