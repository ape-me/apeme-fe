import SwiftUI

/// Attached to the footer, not floating. Icons only, accent when active.
struct TabBar: View {
    @Environment(AppState.self) private var app
    @Environment(\.skin) private var skin

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button { app.root(tab) } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 21, weight: app.tab == tab ? .semibold : .regular))
                        .symbolVariant(app.tab == tab ? .fill : .none)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(app.tab == tab ? skin.accent : Theme.faint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .contentTransition(.symbolEffect(.replace))
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
