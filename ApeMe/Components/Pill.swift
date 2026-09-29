import SwiftUI

/// Fully rounded chip. `on` = accent tint, `filled` = solid accent.
struct Pill: View {
    enum Size { case regular, small, xsmall }
    let label: String
    var on = false
    var filled = false
    var size: Size = .regular
    var icon: String? = nil
    /// Fills the width it is given instead of hugging its label. For a row of equal actions.
    var wide = false
    var action: () -> Void

    @Environment(\.skin) private var skin

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                // A pill is a fixed shape with a word in it. Letting the word wrap turns
                // "Withdraw" into two lines and the pill into a box.
                Text(label).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            .font(.system(size: size == .regular ? 13 : 12, weight: size == .xsmall ? .medium : .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, size == .regular ? 14 : size == .small ? 11 : 10)
            .frame(maxWidth: wide ? .infinity : nil)
            .frame(height: size == .regular ? 36 : size == .small ? 30 : 28)
            .background(bg, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private var fg: Color {
        if filled { return .white }
        if on { return skin.accent }
        return size == .xsmall ? Theme.muted : Theme.ink
    }
    private var bg: Color {
        if filled { return Theme.buy }
        if on { return skin.accentTint }
        return size == .xsmall ? .clear : Theme.surface2
    }
}
