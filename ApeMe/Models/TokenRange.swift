import Foundation

/// Token chart ranges. LIVE is the per-trade tape; the rest are candle closes.
enum TokenRange: String, CaseIterable, Identifiable {
    case live = "LIVE", h1 = "1H", h4 = "4H", all = "ALL"
    var id: String { rawValue }

    /// Candle timeframe and bar count for this range, given the token's age in seconds.
    func candles(age: Int) -> (tf: Timeframe, limit: Int) {
        switch self {
        case .live, .h1: (.m1, 60)
        case .h4: (.m5, 48)
        case .all:
            age < 86400 ? (.m5, 288) : age < 14 * 86400 ? (.h1, 336) : (.d1, 500)
        }
    }
}
