import Foundation

enum Route: Hashable {
    case stock(String)
    case floor(String)
    case token(String)
    case settings
    case referrals
}

enum Tab: String, CaseIterable, Identifiable {
    case home, markets, portfolio, you
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house"; case .markets: "chart.bar"; case .portfolio: "creditcard"; case .you: "person"
        }
    }
    var label: String { self == .portfolio ? "Wallet" : rawValue.capitalized }
}
