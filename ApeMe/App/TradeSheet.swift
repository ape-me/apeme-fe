import Foundation

/// Sheets that can open from any screen.
enum TradeSheet: Identifiable {
    case buyStock(Stock)
    case apeToken(TokenCard, StockRef?)
    case sell(Holding)
    case deposit
    case login
    case tx(Activity)
    case position(Holding)

    var id: String {
        switch self {
        case .buyStock(let s): "buy-\(s.mint)"
        case .apeToken(let t, _): "ape-\(t.mint)"
        case .sell(let h): "sell-\(h.mint)"
        case .deposit: "deposit"
        case .tx(let a): "tx-\(a.id)"
        case .position(let h): "pos-\(h.mint)"
        case .login: "login"
        }
    }
}
