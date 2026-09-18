import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x0b0e12)
    static let surface = Color(hex: 0x12161c)
    static let surface2 = Color(hex: 0x181d25)
    static let line = Color(hex: 0x232a33)
    static let ink = Color(hex: 0xeef2f5)
    static let muted = Color(hex: 0xa7b1bc)
    static let faint = Color(hex: 0x6b7682)
    static let green = Color(hex: 0x5fe39a)
    static let amber = Color(hex: 0xf5b640)
    static let blue = Color(hex: 0x6db3ff)
    static let red = Color(hex: 0xff5c5c)

    static func upDown(_ v: Double?) -> Color {
        guard let v else { return muted }
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

extension Font {
    /// Display: SF Pro Rounded. Numbers: SF Mono via `.mono`.
    static func display(_ size: CGFloat, _ weight: Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func mono(_ size: CGFloat, _ weight: Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}
extension View { func card() -> some View { modifier(Card()) } }
