import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    case insufficientFunds(shortUsd: Double)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): "\(code): \(msg)"
        case .insufficientFunds(let short): "insufficient_usdc · short $\(short)"
        case .transport(let e): e.localizedDescription
        case .decoding: "Unexpected response"
        }
    }
}
