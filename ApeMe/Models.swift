import Foundation

// Mirrors docs/api/contract.ts. Field names are camelCase and stable.

struct Stock: Codable, Identifiable, Hashable {
    var id: String { mint }
    let mint: String
    let symbol: String
    let name: String
    let issuer: String
    let category: String
    let logo: String?
    let priceUsd: Double?
    let change24h: Double?
    let memes: Int
    let marketOpen: Bool
}

/// The subset of Stock embedded in a TokenHeader.
struct StockRef: Codable, Hashable {
    let mint: String
    let symbol: String
    let name: String
    let priceUsd: Double?
    let change24h: Double?
    let marketOpen: Bool
}

enum Phase: String, Codable { case curve, graduated }
enum Side: String, Codable { case buy, sell }
enum Sort: String, CaseIterable, Identifiable {
    case volume, new, mcap
    var id: String { rawValue }
    var label: String {
        switch self { case .volume: "Volume"; case .new: "New"; case .mcap: "Mcap" }
    }
}

enum Timeframe: String, CaseIterable, Identifiable {
    case m1 = "1m", m5 = "5m", m15 = "15m", h1 = "1h", h4 = "4h", d1 = "1d"
    var id: String { rawValue }
    var seconds: Int {
        switch self {
        case .m1: 60; case .m5: 300; case .m15: 900
        case .h1: 3600; case .h4: 14400; case .d1: 86400
        }
    }
}

struct TokenCard: Codable, Identifiable, Hashable {
    var id: String { mint }
    let mint: String
    var symbol: String?
    var name: String?
    var image: String?
    let quoteMint: String
    let launchpad: String
    var phase: Phase
    let createdAt: Int
    var priceQuote: Double?
    var priceUsd: Double?
    var mcapUsd: Double?
    var vol24hUsd: Double
    var buys24h: Int
    var sells24h: Int
    var change24h: Double?
    let taxBps: Int
    var progressPct: Double?
    var lastTradeAt: Int?

    var displaySymbol: String { (symbol?.isEmpty == false ? symbol : nil) ?? Fmt.short(mint) }
    var displayName: String { (name?.isEmpty == false ? name : nil) ?? displaySymbol }
    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}

struct TokenHeader: Codable, Hashable {
    let mint: String
    var symbol: String?
    var name: String?
    var image: String?
    let quoteMint: String
    let launchpad: String
    var phase: Phase
    let createdAt: Int
    var priceQuote: Double?
    var priceUsd: Double?
    var mcapUsd: Double?
    var vol24hUsd: Double
    var buys24h: Int
    var sells24h: Int
    var change24h: Double?
    let taxBps: Int
    var progressPct: Double?
    var lastTradeAt: Int?
    let creator: String?
    let decimals: Int
    let supply: String?
    let curvePool: String?
    let ammPool: String?
    let uri: String?
    let stock: StockRef

    var displaySymbol: String { (symbol?.isEmpty == false ? symbol : nil) ?? Fmt.short(mint) }
    var displayName: String { (name?.isEmpty == false ? name : nil) ?? displaySymbol }
    var imageURL: URL? { image.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
    /// Circulating supply in whole tokens, for recomputing mcap from live prices.
    var supplyTokens: Double? {
        guard let supply, let raw = Double(supply) else { return nil }
        return raw / pow(10, Double(decimals))
    }
}

struct Candle: Codable, Hashable {
    let t: Int
    var o: Double
    var h: Double
    var l: Double
    var c: Double
    var v: Double
    var n: Int
}

struct Trade: Codable, Identifiable, Hashable {
    var id: String { sig }
    let sig: String
    let ts: Int
    let slot: Int
    let side: Side
    let wallet: String
    let base: Double
    let quote: Double
    let priceQuote: Double
    let priceUsd: Double?
}

/// One frame element from /ws/floor or /ws/:mint. Frames are JSON arrays.
struct WsTrade: Codable, Hashable {
    let t: String
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

struct StocksResponse: Codable { let stocks: [Stock]; let asOf: Int }
struct StockTokensResponse: Codable { let stock: Stock; let tokens: [TokenCard]; let next: String? }
struct CandlesResponse: Codable { let mint: String; let tf: String; let candles: [Candle] }
struct TradesResponse: Codable { let mint: String; let trades: [Trade] }
struct ErrorBody: Codable { let error: String; let requestId: String? }
