import Foundation

enum APIError: LocalizedError {
    case http(Int, String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): "\(code): \(msg)"
        case .transport(let e): e.localizedDescription
        case .decoding: "Unexpected response"
        }
    }
}
