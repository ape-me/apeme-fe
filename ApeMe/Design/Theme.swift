import SwiftUI

/// One dark ground, two accents. Values are the prototype's CSS tokens.
enum Theme {
    static let ground = Color(hex: 0x0a0b0d)
    static let surface = Color(hex: 0x16181d)
    static let surface2 = Color(hex: 0x1e2126)
    static let line = Color(hex: 0x23262c)
    static let ink = Color.white
    static let muted = Color(hex: 0xa6a6ae)
    static let faint = Color(hex: 0x75757e)
    static let green = Color(hex: 0x00d632)
    static let red = Color(hex: 0xff5c5c)
    static let amber = Color(hex: 0xf5b640)
    static let amberT = Color(hex: 0x2a2212)
    static let greenT = Color(hex: 0x0f2a17)
    static let redT = Color(hex: 0x2a1517)
    static let greyT = Color(hex: 0x1e2126)

    /// Green / red for 24h change and P&L only.
    static func change(_ v: Double?) -> Color {
        guard let v else { return faint }
        return v >= 0 ? green : red
    }
    static func side(_ s: Side) -> Color { s == .buy ? green : red }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }
}
