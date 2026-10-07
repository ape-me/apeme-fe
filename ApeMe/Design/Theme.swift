import SwiftUI

/// Two palettes, one set of names. Every token is a light/dark pair resolved by the system, so a
/// screen never asks which mode it is in — it asks for `Theme.surface` and gets the right one.
/// The dark values are the prototype's CSS tokens; the light ones are picked to sit the same
/// distance apart, with a slight cool bias so the greys read as chosen rather than default.
enum Theme {
    static let ground   = Color(light: 0xF5F6F8, dark: 0x0a0b0d)
    static let surface  = Color(light: 0xFFFFFF, dark: 0x16181d)
    static let surface2 = Color(light: 0xEEF0F3, dark: 0x1e2126)
    static let line     = Color(light: 0xE3E5EA, dark: 0x23262c)
    static let ink      = Color(light: 0x0B0B0C, dark: 0xFFFFFF)
    static let muted    = Color(light: 0x5F6370, dark: 0xa6a6ae)
    static let faint    = Color(light: 0x8A8E99, dark: 0x75757e)
    /// Darker on white than on black: the same green that pops on a dark ground washes out on a light one.
    static let green    = Color(light: 0x0F9D3F, dark: 0x00d632)
    static let red      = Color(light: 0xD93F3F, dark: 0xff5c5c)
    static let amber    = Color(light: 0xB7791F, dark: 0xf5b640)
    static let amberT   = Color(light: 0xFFF3DC, dark: 0x2a2212)
    static let greenT   = Color(light: 0xE3F7EA, dark: 0x0f2a17)
    static let redT     = Color(light: 0xFDE4E4, dark: 0x2a1517)
    static let greyT    = Color(light: 0xEEF0F3, dark: 0x1e2126)

    /// Trade buttons: Phantom's green and red, white text, same in both modes.
    static let buy = Color(hex: 0x3fa86a)
    static let buyHi = Color(hex: 0x53bd7c)
    static let sell = Color(hex: 0xe4522f)
    static let sellHi = Color(hex: 0xf06a45)
    static var buyGradient: LinearGradient { LinearGradient(colors: [buyHi, buy], startPoint: .top, endPoint: .bottom) }
    static var sellGradient: LinearGradient { LinearGradient(colors: [sellHi, sell], startPoint: .top, endPoint: .bottom) }

    /// Green / red for 24h change and P&L only.
    static func change(_ v: Double?) -> Color {
        guard let v else { return faint }
        return v >= 0 ? green : red
    }
    static func side(_ s: Side) -> Color { s == .buy ? green : red }
}

extension Color {
    /// Resolved per trait collection, so the pair swaps with the system setting live.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }

    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }
}
