import SwiftUI

/// "Ape mode" label + iOS switch. Lives on Home (top right) and in You.
struct ModeSwitch: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin

    var body: some View {
        Button { app.toggleMode() } label: {
            HStack(spacing: 10) {
                Text("Ape mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(app.isApe ? Theme.ink : Theme.muted)
                SwitchShape(on: app.isApe, tint: skin.accent)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(app.isApe ? "on" : "off")
    }
}

struct SwitchShape: View {
    let on: Bool
    let tint: Color
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? tint : Theme.surface2)
            Circle().fill(.white)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                .padding(2)
        }
        .frame(width: 51, height: 31)
        .animation(.easeOut(duration: 0.2), value: on)
    }
}
