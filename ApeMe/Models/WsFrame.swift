import Foundation

/// One element of a WebSocket frame. Frames are JSON arrays; unknown `t` values are dropped.
enum WsFrame: Hashable {
    case trade(WsTrade)
    case token(mint: String, event: String)
    case price(WsPrice)
    case news(WsNews)
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
    let kind: String?          // "stock" | "meme"
    let ts: Int
    let priceUsd: Double?
    let markUsd: Double?
    let change24h: Double?
}

struct WsTrade: Codable, Hashable {
    let mint: String
    let sig: String
    let ts: Int
    let slot: Int
    let side: Side
    let wallet: String
    let base: Double
    let quote: Double
    let priceQuote: Double
    let priceUsd: Double?

    var trade: Trade {
        Trade(sig: sig, ts: ts, slot: slot, side: side, wallet: wallet,
              base: base, quote: quote, priceQuote: priceQuote, priceUsd: priceUsd)
    }
}

struct RawWsFrame: Decodable {
    let frame: WsFrame?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        let t = try c.decode(String.self, forKey: .t)
        switch t {
        case "trade":
            frame = (try? WsTrade(from: decoder)).map(WsFrame.trade)
        case "token":
            let mint = try c.decode(String.self, forKey: .mint)
            let event = (try? c.decode(String.self, forKey: .event)) ?? "created"
            frame = .token(mint: mint, event: event)
        case "price":
            frame = (try? WsPrice(from: decoder)).map(WsFrame.price)
        case "news":
            frame = (try? WsNews(from: decoder)).map(WsFrame.news)
        default:
            frame = nil
        }
    }
    private enum Key: String, CodingKey { case t, mint, event }
}
