import Foundation

/// One element of a WebSocket frame. Frames are JSON arrays; unknown `t` values are dropped.
enum WsFrame: Hashable {
    case price(WsPrice)
    case news(WsNews)
    case order(WsOrder)
}

/// Arrives on the user's own channel the moment a limit order finishes.
struct WsOrder: Codable, Hashable {
    let id: String
    let mint: String?
    let symbol: String?
    let side: String?
    let status: String?            // "filled" | "partial" | "cancelled"
    let fillUsd: Double?
    /// Present on a partial: what has been taken so far and what the order was for.
    let filledUsd: Double?
    let makingUsd: Double?
    let signature: String?
}

/// `stock:<mint>` announces a headline the moment it lands. Enough to flag the tab; the list refetches.
struct WsNews: Codable, Hashable {
    let mint: String
    let symbol: String?
    let title: String?
    let source: String?
    let url: String?
    let publishedAt: Int?
}

/// Jupiter-sampled stock price on `stock:<mint>`, at most one per 5s, only when it moved.
struct WsPrice: Codable, Hashable {
    let mint: String
    let kind: String?
    let ts: Int
    let priceUsd: Double?
    let markUsd: Double?
    let change24h: Double?
}

struct RawWsFrame: Decodable {
    let frame: WsFrame?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        let t = try c.decode(String.self, forKey: .t)
        switch t {
        case "price":
            frame = (try? WsPrice(from: decoder)).map(WsFrame.price)
        case "news":
            frame = (try? WsNews(from: decoder)).map(WsFrame.news)
        case "order":
            frame = (try? WsOrder(from: decoder)).map(WsFrame.order)
        default:
            frame = nil
        }
    }
    private enum Key: String, CodingKey { case t }
}
