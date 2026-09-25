import SwiftUI

/// One label → value line inside a `KCard`.
struct KV<Value: View>: View {
    let label: String
    @ViewBuilder let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            value
                .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
        .frame(minHeight: 40)
    }
}

extension KV where Value == Text {
    init(_ label: String, _ text: String) {
        self.init(label) { Text(text) }
    }
}

/// Surface card whose rows are separated by hairlines.
struct KCard<Content: View>: View {
    var padded = false
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            if padded {
                content.padding(16)
            } else {
                _VariadicView.Tree(HairlineRows()) { content }
                    .padding(.horizontal, 16).padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }
}

private struct HairlineRows: _VariadicView_MultiViewRoot {
    @ViewBuilder func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != last {
                    Divider().overlay(Theme.line)
                }
            }
        }
    }
}

struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .semibold)).tracking(-0.3)
            Spacer()
            trailing
        }
        .padding(.bottom, 10)
    }
}

/// One cell of a `StatGrid`. The value is a `Text` so a caller can colour it — a `Text`'s own
/// style survives the grid's.
struct Stat: Identifiable {
    let label: String
    let value: Text
    var id: String { label }

    init(_ label: String, _ value: Text) {
        self.label = label
        self.value = value
    }
}

/// Four numbers in a 2×2, hairlined into quarters. Four full-width `KV` rows spend twice the
/// height on the same four numbers, which on a medium sheet is the difference between the
/// buttons being on screen and not. The label sits above the value because a half-width cell
/// has no room for the leader gap a full-width row leans on.
struct StatGrid: View {
    let stats: [Stat]

    var body: some View {
        let rows = stride(from: 0, to: stats.count, by: 2).map { Array(stats[$0..<min($0 + 2, stats.count)]) }
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if i > 0 { Divider().overlay(Theme.line) }
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { j, stat in
                        if j > 0 { Divider().overlay(Theme.line) }
                        cell(stat)
                    }
                    if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                }
                .frame(minHeight: 60)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
    }

    private func cell(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(stat.label).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
            stat.value
                .font(.system(size: 16, weight: .semibold)).monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
