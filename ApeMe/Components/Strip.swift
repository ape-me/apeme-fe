import SwiftUI

/// Horizontal ticker strip: symbol, price, arrow.
struct StripItem: Identifiable, Hashable {
    let id: String
    let label: String
    let price: Double?
    let change: Double?
}

struct Strip: View {
    let items: [StripItem]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                ForEach(items) { it in
                    HStack(spacing: 6) {
                        Text(it.label).foregroundStyle(Theme.muted)
                        Text(Fmt.usd(it.price))
                        Text(Fmt.arrow(it.change, 1)).foregroundStyle(Theme.change(it.change))
                    }
                    .font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
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

    var body: some View {
        HStack {
            ForEach(items) { it in
                let on = it == selected
                Button { onSelect(it) } label: {
                    Text(label(it))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? skin.accent : Theme.muted)
                        .frame(width: 44, height: 32)
                        .background(on ? skin.accentTint : .clear, in: .capsule)
                }
                .buttonStyle(.plain)
                if it != items.last || trailing != nil { Spacer(minLength: 0) }
            }
            if let trailing { trailing }
        }
        .padding(.horizontal, 8)
    }
}
