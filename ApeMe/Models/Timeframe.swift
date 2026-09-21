import Foundation

enum Timeframe: String, CaseIterable, Identifiable {
    case m1 = "1m", m5 = "5m", m15 = "15m", h1 = "1h", h4 = "4h", d1 = "1d"
    var id: String { rawValue }
    var seconds: Int {
        switch self {
        case .m1: 60; case .m5: 300; case .m15: 900
        case .h1: 3600; case .h4: 14400; case .d1: 86400
        }
    }
}
