import Foundation

enum HistoryRange: String, CaseIterable, Identifiable {
    case m5 = "5m", m15 = "15m", h1 = "1h", d1 = "1d", w1 = "1w", m1 = "1m"
    var id: String { rawValue }
    var label: String {
        switch self { case .m5: "5M"; case .m15: "15M"; case .h1: "1H"; case .d1: "1D"; case .w1: "7D"; case .m1: "30D" }
    }
    var caption: String {
        switch self {
        case .m5: "past 5 min"; case .m15: "past 15 min"; case .h1: "past hour"
        case .d1: "today"; case .w1: "past 7 days"; case .m1: "past 30 days"
        }
    }
    /// Seconds per point, for appending live prices onto the loaded series.
    var bucket: Int {
        switch self { case .m5: 5; case .m15: 15; case .h1: 60; case .d1: 120; case .w1: 3600; case .m1: 86400 }
    }
}
