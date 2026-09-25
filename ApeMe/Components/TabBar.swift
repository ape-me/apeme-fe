import SwiftUI

/// Attached to the footer, not floating. Icon over word, accent when active — a wallet
/// and a person glyph are not distinguishable enough at this size to stand alone.
struct TabBar: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button { app.root(tab) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: app.tab == tab ? .semibold : .regular))
                            .symbolVariant(app.tab == tab ? .fill : .none)
                            .symbolRenderingMode(.hierarchical)
                            .contentTransition(.symbolEffect(.replace))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(app.tab == tab ? skin.accent : Theme.faint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, 8).padding(.top, 4)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
