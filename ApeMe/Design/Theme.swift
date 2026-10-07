import SwiftUI

/// Zoneless palette, light only. Names unchanged so no screen had to move. Every token is a light/dark pair resolved by the system, so a
/// screen never asks which mode it is in — it asks for `Theme.surface` and gets the right one.
/// The dark values are the prototype's CSS tokens; the light ones are picked to sit the same
/// distance apart, with a slight cool bias so the greys read as chosen rather than default.
enum Theme {
    static let accent   = Color(hex: 0x0055FF)
    static let ground   = Color(hex: 0xF8FAFC)
    static let surface  = Color(hex: 0xFFFFFF)
    static let surface2 = Color(hex: 0xEEF2F7)
    static let line     = Color(hex: 0xE2E8F0)
    static let ink      = Color(hex: 0x1E293B)
    /// Solid slate steps rather than the ink at reduced opacity: on 13pt mobile type the
    /// opacity version read as dull, and these keep the same hue family with more weight.
    static let muted    = Color(hex: 0x475569)
    static let faint    = Color(hex: 0x64748B)
    static let green    = Color(hex: 0x059669)
    static let red      = Color(hex: 0xDC2626)
    static let amber    = Color(hex: 0xB45309)
    static let amberT   = Color(hex: 0xFEF3C7)
    static let greenT   = Color(hex: 0xD1FAE5)
    static let redT     = Color(hex: 0xFEE2E2)
    static let greyT    = Color(hex: 0xEEF2F7)

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
