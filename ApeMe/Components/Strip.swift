import SwiftUI

/// Horizontal ticker strip: symbol, price, arrow.
struct StripItem: Identifiable, Hashable {
    enum Kind { case stock, meme }
    let id: String
    let kind: Kind
    let label: String
    let price: Double?
    let change: Double?
}

struct Strip: View {
    let items: [StripItem]
    @Environment(AppState.self) private var app
    /// Tap any change figure to flip the whole strip between `↑ 3.1%` and `↑ $32.10`.
    @State private var showAmount = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                ForEach(items) { it in
                    HStack(spacing: 6) {
                        Button {
                            switch it.kind {
                            case .stock: app.openStock(it.id)
                            case .meme: app.push(.token(it.id))
                            }
                        } label: {
                            Text(it.label).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        // Groww-style change chip: bold figure on a light green/red tint.
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { showAmount.toggle() }
                        } label: {
                            Text(change(it))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.change(it.change))
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.35), value: it.change)
                                .padding(.horizontal, 7).frame(height: 22)
                                .background((it.change ?? 0) >= 0 ? Theme.greenT : Theme.redT, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .monospacedDigit()
                }
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func change(_ it: StripItem) -> String {
        guard showAmount, let pct = it.change, let price = it.price else { return Fmt.arrow(it.change, 1) }
        let delta = price - price / (1 + pct / 100)
        return (delta >= 0 ? "↑ " : "↓ ") + Fmt.usd(abs(delta))
    }
}

/// Underlined text tabs.
struct UnderlineTabs<T: Hashable & Identifiable>: View {
    let items: [T]
    let selected: T
    var fill = false
    let label: (T) -> String
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: fill ? 0 : 14) {
            ForEach(items) { it in
                let on = it == selected
                Button { onSelect(it) } label: {
                    Text(label(it))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(on ? Theme.ink : Theme.faint)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: fill ? .infinity : nil)
                        .frame(height: 40)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(on ? Theme.ink : .clear).frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Range pills (1H 1D 1W 1M) spread across the width.
struct RangePills<T: Hashable & Identifiable>: View {
    let items: [T]
    let selected: T
    let label: (T) -> String
    let onSelect: (T) -> Void
    var trailing: AnyView? = nil
    @Environment(\.skin) private var skin

    /// Space-evenly: the same gap between pills and at both edges.
    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ForEach(items) { it in
                let on = it == selected
                Button { onSelect(it) } label: {
                    Text(label(it))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? skin.accent : Theme.muted)
                        .frame(width: 52, height: 32)
                        .background(on ? skin.accentTint : .clear, in: .capsule)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            if let trailing { trailing; Spacer(minLength: 0) }
        }
    }
}
