import Foundation

enum Route: Hashable {
    case stock(String)
    case floor(String)
    case token(String)
}

enum Tab: String, CaseIterable, Identifiable {
    case home, markets, portfolio, you
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: "house"; case .markets: "chart.bar"; case .portfolio: "clock"; case .you: "person"
        }
    }
    var label: String { rawValue.capitalized }
}
