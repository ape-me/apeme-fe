import Foundation

enum Route: Hashable {
    case stock(String)
    case floor(String)
    case token(String)
    case settings
    case referrals

    /// Destinations that belong to the meme side, and are unreachable while it is hidden.
    var needsApe: Bool {
        switch self {
        case .floor, .token: true
        case .stock, .settings, .referrals: false
        }
    }
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
