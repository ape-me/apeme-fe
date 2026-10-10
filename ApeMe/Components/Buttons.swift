import SwiftUI

/// 52pt fully rounded buttons. `.primary` = accent, `.cta` = gradient, `.ghost` = surface.
struct BigButton: View {
    enum Style { case primary, cta, buy, sell, white, ghost, danger, off }
    let label: String
    var style: Style = .primary
    var small = false
    var action: () -> Void

    @Environment(\.skin) private var skin

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.instrument(small ? 14 : 16, 600))
                .tracking(-0.2)
                .foregroundStyle(fg)
                .padding(.horizontal, small ? 16 : 20)
                .frame(maxWidth: .infinity)
                .frame(height: small ? 40 : 52)
                .background(AnyShapeStyle(background), in: .rect(cornerRadius: 8))
                // Zoneless buttons are outlines. Only Buy and Sell keep a fill — a trading app
                // needs those two to shout, and they are the two colours the palette allows.
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1.5))
        }
        .buttonStyle(PressScale())
    }

    private var fg: Color {
        switch style {
        case .primary, .white: Theme.accent
        case .buy, .sell, .cta: .white
        case .ghost: Theme.ink
        case .danger: Theme.red
        case .off: Theme.faint
        }
    }
    private var background: AnyShapeStyle {
        switch style {
        case .buy: AnyShapeStyle(Theme.buyGradient)
        case .sell: AnyShapeStyle(Theme.sellGradient)
        // The one filled accent button a screen is allowed: the single thing to press on it.
        case .cta: AnyShapeStyle(Theme.accent)
        default: AnyShapeStyle(Color.clear)
        }
    }
    private var border: Color {
        switch style {
        case .primary, .white: Theme.accent
        case .danger: Theme.red
        case .buy, .sell, .cta: .clear
        case .ghost, .off: Theme.line
        }
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// 40pt round icon button on surface2.
struct IconButton: View {
    let symbol: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.surface2, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        IconButton(symbol: "chevron.left", label: "Back") { dismiss() }
    }
}


/// Rows had no reaction to a tap at all, which reads as dead. A tint on press rather than a
/// scale: a full-width row that shrinks looks like it is peeling off the screen.
struct RowPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.ink.opacity(0.05) : .clear,
                        in: .rect(cornerRadius: 12))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
