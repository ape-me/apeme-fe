import SwiftUI

/// The accent set for the current mode. Invest = blue, Ape = green.
struct Skin: Equatable {
    let mode: Mode
    var accent: Color { mode == .ape ? Theme.green : Color(hex: 0x578bfa) }
    var accentInk: Color { mode == .ape ? Theme.ground : .white }
    var accentTint: Color { mode == .ape ? Color(hex: 0x0f2a17) : Color(hex: 0x17233f) }
    var cta: LinearGradient {
        LinearGradient(
            colors: mode == .ape ? [Color(hex: 0x00d632), Color(hex: 0x5ff08a)] : [Color(hex: 0x4f7bf7), Color(hex: 0x6cc7f0)],
            startPoint: .leading, endPoint: .trailing)
    }
    var isApe: Bool { mode == .ape }
}

extension EnvironmentValues {
    @Entry var skin = Skin(mode: .invest)
}
