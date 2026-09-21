import SwiftUI

/// 52pt fully rounded buttons. `.primary` = accent, `.cta` = gradient, `.ghost` = surface.
struct BigButton: View {
    enum Style { case primary, cta, white, ghost, danger, off }
    let label: String
    var style: Style = .primary
    var small = false
    var action: () -> Void

    @Environment(\.skin) private var skin

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(small ? .system(size: 14, weight: .semibold) : .button)
                .tracking(-0.2)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .frame(height: small ? 40 : 52)
                .background(AnyShapeStyle(background), in: .capsule)
        }
        .buttonStyle(PressScale())
    }

    private var fg: Color {
        switch style {
        case .primary, .cta: skin.accentInk
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
