import Foundation

enum Route: Hashable {
    case stock(String)
    case settings
    case referrals

    /// Whether this destination is switched on. `push` refuses anything that is not.
    var isAvailable: Bool {
        switch self {
        case .referrals: Feature.referrals
        case .stock, .settings: true
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case home, markets, portfolio, you
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house"
        case .markets: "chart.line.uptrend.xyaxis"
        case .portfolio: "wallet.bifold"
        case .you: "person.crop.circle"
        }
    }
    var label: String { self == .portfolio ? "Wallet" : rawValue.capitalized }
}
