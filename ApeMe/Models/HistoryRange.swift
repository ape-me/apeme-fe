import Foundation

enum HistoryRange: String, CaseIterable, Identifiable {
    case h1 = "1h", d1 = "1d", w1 = "1w", m1 = "1m"
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var caption: String {
        switch self {
        case .h1: "past hour"; case .d1: "today"; case .w1: "past week"; case .m1: "past month"
        }
    }
}
