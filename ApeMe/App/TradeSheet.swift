import Foundation

/// Sheets that can open from any screen.
enum TradeSheet: Identifiable {
    case buyStock(Stock)
    case sell(Holding)
    case deposit
    case withdraw
    /// Open a basket (buy every leg) or close one (sell every leg).
    case basket(BasketDetail, amountUsd: Double, weights: [String: Int]? = nil)
    case closeBasket(BasketPosition)
    case login
    case tx(Activity)
    case resume(TradeResume)
    /// A basket order that ran behind a toast and needs the sheet back: a partial fill, a
    /// failure, or fresh prices to confirm.
    case resumeBasket(BasketResume)
    case position(Holding)

    var id: String {
        switch self {
        case .buyStock(let s): "buy-\(s.mint)"
        case .sell(let h): "sell-\(h.mint)"
        case .deposit: "deposit"
        case .withdraw: "withdraw"
        case .basket(let b, _, _): "basket-\(b.id)"
        case .closeBasket(let p): "close-basket-\(p.basketId)"
        case .tx(let a): "tx-\(a.id)"
        case .resume(let r): "resume-\(r.id)"
        case .resumeBasket(let r): "resume-basket-\(r.id)"
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

/// Everything the basket sheet needs to come back around an order that already ran.
struct BasketResume: Identifiable {
    let id = UUID()
    let store: BasketOrderStore
    let tagline: String?
    let logos: [URL]
    let amountUsd: Double
    var name: String { store.name }
    var sell: Bool { store.sell }
}
