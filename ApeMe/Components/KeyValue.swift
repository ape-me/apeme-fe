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
        .frame(minHeight: 46)
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
