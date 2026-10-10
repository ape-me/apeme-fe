import SwiftUI
import UIKit

/// Instrument Sans throughout — the one variable file, weighted through its wght axis — with
/// Zoneless's tight tracking on headings. Numbers take tabular figures.
extension Font {
    static func instrument(_ size: CGFloat, _ weight: CGFloat = 400) -> Font {
        let base = UIFont(name: "InstrumentSans-Regular", size: size) ?? .systemFont(ofSize: size)
        let desc = base.fontDescriptor.addingAttributes([
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [0x77676874: weight],   // 'wght'
        ])
        return Font(UIFont(descriptor: desc, size: size))
    }

    static let hero = instrument(40, 600)
    static let h1 = instrument(28, 600)
    static let h2 = instrument(18, 600)
    static let h3 = instrument(15, 600)
    static let body15 = instrument(15)
    static let sub = instrument(13)
    static let eyebrow = instrument(13, 500)
    static let badge = instrument(11, 600)
    static let rowTitle = instrument(15, 600)
    static let rowPrice = instrument(15, 600)
    static let rowChange = instrument(13, 500)
    static let pill = instrument(13, 600)
    static let button = instrument(16, 600)
    static let stat = instrument(17, 600)
    /// The entry amount is the one place a digit stands alone at poster size, and Instrument
    /// Sans's flat-sided zero reads as cut off there. The system face, like the stock price.
    static let amount = Font.system(size: 56, weight: .semibold)
}

extension View {
    func numeric() -> some View { monospacedDigit() }
    func heroText() -> some View { font(.hero).tracking(-1.2).monospacedDigit().foregroundStyle(Theme.accent) }
    /// Headings carry the accent: on Zoneless the blue is reserved for titles, links and outlines.
    func h1Text() -> some View { font(.h1).tracking(-0.84).foregroundStyle(Theme.accent) }
    func h2Text() -> some View { font(.h2).tracking(-0.54).foregroundStyle(Theme.accent) }
    func h3Text() -> some View { font(.h3).tracking(-0.3) }
}
