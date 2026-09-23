import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    case insufficientFunds(shortUsd: Double)
    /// The BE states the rule it enforced; the UI adopts it rather than guessing.
    case orderRefused(reason: String, minUsd: Double?, excludedIssuers: [String]?)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): "\(code): \(msg)"
        case .insufficientFunds(let short): "insufficient_usdc · short $\(short)"
        case .orderRefused(let reason, _, _): reason
        case .transport(let e): e.localizedDescription
        case .decoding: "Unexpected response"
        }
    }
}
