import SwiftUI

/// The prototype's type scale. SF Pro throughout, tabular numerals on anything numeric.
extension Font {
    static let hero = Font.system(size: 40, weight: .semibold)
    static let h1 = Font.system(size: 28, weight: .semibold)
    static let h2 = Font.system(size: 18, weight: .semibold)
    static let h3 = Font.system(size: 15, weight: .semibold)
    static let body15 = Font.system(size: 15)
    static let sub = Font.system(size: 13)
    static let eyebrow = Font.system(size: 13, weight: .medium)
    static let badge = Font.system(size: 11, weight: .semibold)
    static let rowTitle = Font.system(size: 15, weight: .semibold)
    static let rowPrice = Font.system(size: 15, weight: .semibold)
    static let rowChange = Font.system(size: 13, weight: .medium)
    static let pill = Font.system(size: 13, weight: .semibold)
    static let button = Font.system(size: 16, weight: .semibold)
    static let stat = Font.system(size: 17, weight: .semibold)
    static let amount = Font.system(size: 56, weight: .semibold)
}

extension View {
    /// Tabular figures plus the tight tracking the prototype uses on numbers.
    func numeric() -> some View { monospacedDigit() }
    func heroText() -> some View { font(.hero).tracking(-1.8).monospacedDigit() }
    func h1Text() -> some View { font(.h1).tracking(-0.98) }
    func h2Text() -> some View { font(.h2).tracking(-0.45) }
    func h3Text() -> some View { font(.h3).tracking(-0.22) }
}
