import SwiftUI

struct Badge: View {
    enum Style { case amber, grey, green, red, accent }
    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(.badge).monospacedDigit()
            .foregroundStyle(fg)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(bg, in: .rect(cornerRadius: 6))
    }

    private var fg: Color {
        switch style { case .amber: Theme.amber; case .grey: Theme.muted; case .green: Theme.green; case .red: Theme.red; case .accent: Theme.ink }
    }
    private var bg: Color {
        switch style { case .amber: Theme.amberT; case .grey: Theme.greyT; case .green: Theme.greenT; case .red: Theme.redT; case .accent: Theme.surface2 }
    }
}

/// Premium to fair value. Grey under 5%, amber at or above. Never green or red.
struct PremiumBadge: View {
    let pct: Double?
    var body: some View {
        if let pct {
            Badge(text: Fmt.pct(pct, 1), style: abs(pct) >= 5 ? .amber : .grey)
        }
    }
}
