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
                .font(small ? .system(size: 14, weight: .semibold) : .system(size: 17, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(fg)
                .padding(.horizontal, small ? 16 : 20)
                .frame(maxWidth: .infinity)
                .frame(height: small ? 40 : 52)
                .background(AnyShapeStyle(background), in: .capsule)
        }
        .buttonStyle(PressScale())
    }

    private var fg: Color {
        switch style {
        case .primary, .cta: skin.accentInk
        case .buy, .sell: .white
        case .white: Theme.ground
        case .ghost: Theme.ink
        case .danger: Theme.red
        case .off: Theme.faint
        }
    }
    private var background: AnyShapeStyle {
        switch style {
        case .primary: AnyShapeStyle(skin.accent)
        case .cta: AnyShapeStyle(skin.cta)
        case .buy: AnyShapeStyle(Theme.buyGradient)
        case .sell: AnyShapeStyle(Theme.sellGradient)
        case .white: AnyShapeStyle(Color.white)
        case .ghost, .danger, .off: AnyShapeStyle(Theme.surface2)
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
            .background(configuration.isPressed ? Color.white.opacity(0.05) : .clear,
                        in: .rect(cornerRadius: 12))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
