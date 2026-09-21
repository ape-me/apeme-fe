import Foundation

/// Stock chart ranges. LIVE is the 5s series plus socket price frames; ALL is everything we have.
enum HistoryRange: String, CaseIterable, Identifiable {
    case live, h1, d1, w1, m1, all
    var id: String { rawValue }

    var label: String {
        switch self { case .live: "LIVE"; case .h1: "1H"; case .d1: "1D"; case .w1: "7D"; case .m1: "30D"; case .all: "ALL" }
    }
    var caption: String {
        switch self {
        case .live: "live"; case .h1: "past hour"; case .d1: "today"
        case .w1: "past 7 days"; case .m1: "past 30 days"; case .all: "all time"
        }
    }
    /// The backend range. ALL rides on 1m until a `range=all` exists; history is younger than that anyway.
    var api: String {
        switch self { case .live: "5m"; case .h1: "1h"; case .d1: "1d"; case .w1: "1w"; case .m1, .all: "1m" }
    }
    /// Seconds per point, for appending live prices onto the loaded series.
    var bucket: Int {
        switch self { case .live: 5; case .h1: 60; case .d1: 120; case .w1: 3600; case .m1, .all: 86400 }
    }
    /// The two that live behind the ▾ pill.
    static let long: [HistoryRange] = [.w1, .m1]
}
