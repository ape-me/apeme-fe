import Foundation

/// Sheets that can open from any screen.
enum TradeSheet: Identifiable {
    case buyStock(Stock)
    case apeToken(TokenCard, StockRef?)
    case sell(Holding)
    case deposit
    case login
    case tx(Activity)
    case resume(TradeResume)
    case position(Holding)

    var id: String {
        switch self {
        case .buyStock(let s): "buy-\(s.mint)"
        case .apeToken(let t, _): "ape-\(t.mint)"
        case .sell(let h): "sell-\(h.mint)"
        case .deposit: "deposit"
        case .tx(let a): "tx-\(a.id)"
        case .resume(let r): "resume-\(r.id)"
        case .position(let h): "pos-\(h.mint)"
        case .login: "login"
        }
    }
}

/// Everything needed to put a trade sheet back exactly where it was (review step) after a failure.
struct TradeResume: Identifiable {
    let id = UUID()
    let store: TradeStore
    let side: TradeStore.Side
    let asset: TradeSheetView.Asset
    let amount: String
    let pct: Double?
    var sellQty: Double {
        guard let h = store.holding, let v = h.valueUsd, v > 0 else { return 0 }
        return h.amount * min(Double(amount) ?? 0, v) / v
    }
}
