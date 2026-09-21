import Foundation

enum HistoryRange: String, CaseIterable, Identifiable {
    case h1 = "1h", d1 = "1d", w1 = "1w", m1 = "1m"
    var id: String { rawValue }
    var label: String {
        switch self { case .h1: "1H"; case .d1: "1D"; case .w1: "7D"; case .m1: "30D" }
    }
    var caption: String {
        switch self {
        case .h1: "past hour"; case .d1: "today"; case .w1: "past 7 days"; case .m1: "past 30 days"
        }
    }
}
