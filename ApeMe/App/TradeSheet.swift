import Foundation

/// Sheets that can open from any screen.
enum TradeSheet: Identifiable {
    case buyStock(Stock)
    case apeToken(TokenCard, StockRef?)
    case deposit

    var id: String {
        switch self {
        case .buyStock(let s): "buy-\(s.mint)"
        case .apeToken(let t, _): "ape-\(t.mint)"
        case .deposit: "deposit"
        }
    }
}
