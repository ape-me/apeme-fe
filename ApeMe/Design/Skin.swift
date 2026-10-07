import SwiftUI

/// The app's accent set. One skin now that there is one product.
struct Skin: Equatable {
    var accent: Color { Theme.accent }
    var accentInk: Color { .white }
    var accentTint: Color { Color(hex: 0x0055FF).opacity(0.10) }
    var cta: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x4f7bf7), Color(hex: 0x6cc7f0)], startPoint: .leading, endPoint: .trailing)
    }
}

extension EnvironmentValues {
    @Entry var skin = Skin()
}
